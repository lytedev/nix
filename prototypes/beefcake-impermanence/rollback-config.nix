# P1b — the REAL impermanence mechanism, as it would run on beefcake (or the
# thin host, or the guest OS zvol): ZFS root with a @blank snapshot rolled
# back on every boot by a systemd-initrd service.
#
# The widely-copied `boot.initrd.postDeviceCommands` hook silently does
# nothing under systemd-initrd; this config carries the corrected form — a
# proper initrd unit ordered after the pool import and before /sysroot mounts.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  system.stateVersion = "24.05";
  networking.hostName = "rollback-proto";
  networking.hostId = "deadbeef";

  # Keep the image closure small: the default flake-registry/NIX_PATH pins
  # would embed the entire nixpkgs source tree (~100k files), which blows the
  # image-build VM's fd limits and the image size.
  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;
  documentation.enable = false;

  disko.devices = {
    disk.main = {
      device = "/dev/vda";
      type = "disk";
      imageSize = "4G";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "256M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };
    zpool.rpool = {
      type = "zpool";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        mountpoint = "none";
      };
      datasets = {
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          # The blank snapshot the initrd rolls back to. postCreateHook runs
          # at disko format time, before nixos-install populates the root.
          postCreateHook = "zfs snapshot rpool/local/root@blank";
        };
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.atime = "off";
        };
        "safe/persist" = {
          type = "zfs_fs";
          # legacy ZFS property so the fileSystems entry below drives it and
          # systemd-initrd mounts it in STAGE-1 as sysroot-persist.mount —
          # required for persist-machine-id to seed machine-id before
          # switch-root. Mirrors beefcake's rpool/persist (mountpoint=legacy).
          options.mountpoint = "legacy";
        };
      };
    };
  };

  fileSystems."/persist" = {
    device = "rpool/safe/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  boot = {
    loader.systemd-boot.enable = true;
    # No persistent EFI varstore in the image-build VM or under `-bios OVMF`;
    # systemd-boot installs to the EFI/BOOT/BOOTX64.EFI fallback path instead.
    loader.efi.canTouchEfiVariables = false;
    initrd.systemd.enable = true;
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems = [ "zfs" ];
    # The pool is created by disko's image-build VM under a different hostid,
    # so the first boot MUST force-import; without it zfs-import-rpool fails
    # and the whole /sysroot tree (and the rollback unit) dependency-fails
    # into emergency mode. Real-hardware blue/green does NOT need this: both
    # slots share a hostId and the cutover exports cleanly (proven by the
    # handoff test).
    zfs.forceImportRoot = true;
    # qemu virtio-blk disks carry no serial, so /dev/disk/by-id (the default
    # devNodes) is EMPTY and `zpool import` waits forever. by-path always
    # exists.
    zfs.devNodes = "/dev/disk/by-path";

    # THE mechanism under test: wipe / on every boot, after the pool is
    # imported, before the root is mounted at /sysroot.
    initrd.systemd.services.rollback-root = {
      description = "Rollback rpool/local/root to @blank (impermanence)";
      wantedBy = [ "initrd.target" ];
      # requires (not just after): if the import fails, don't run — otherwise
      # the unit fires pointlessly in emergency mode and muddies the journal.
      requires = [ "zfs-import-rpool.service" ];
      after = [ "zfs-import-rpool.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        zfs rollback -r rpool/local/root@blank
        echo "rolled back rpool/local/root to @blank"
      '';
    };

    # FLIP-ATTEMPT-#1 REGRESSION GUARD (2026-07-08): reproduce + fix the
    # machine-id-absent-at-PID1 → first-boot → dbus crash-loop that took
    # beefcake down. Seed /etc/machine-id from /persist (self-seeding) BEFORE
    # switch-root, so PID1 never generates a random transient id / declares
    # ConditionFirstBoot. Mirrors packages/hosts/beefcake/impermanence.nix.
    initrd.systemd.services.persist-machine-id = {
      description = "Seed /etc/machine-id from /persist before switch-root";
      wantedBy = [ "initrd.target" ];
      requires = [
        "sysroot.mount"
        "sysroot-persist.mount"
      ];
      after = [
        "rollback-root.service"
        "sysroot.mount"
        "sysroot-persist.mount"
      ];
      before = [ "initrd-switch-root.target" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /sysroot/persist/etc /sysroot/etc
        if [ ! -s /sysroot/persist/etc/machine-id ]; then
          tr -d - < /proc/sys/kernel/random/uuid > /sysroot/persist/etc/machine-id
          echo "generated new machine-id into /persist"
        fi
        cp /sysroot/persist/etc/machine-id /sysroot/etc/machine-id
        chmod 0444 /sysroot/etc/machine-id
        echo "seeded /etc/machine-id before switch-root"

        # FLIP-ATTEMPT-#2 SECOND-ROOT-CAUSE REGRESSION GUARD (2026-07-08):
        # reproduce the /var-parent-perms bug deterministically. On beefcake the
        # /persist source parents were mode 0700, and impermanence propagates
        # the source mode onto the ephemeral bind-mount parents — so /var came
        # up 0700 and every non-root service user was blocked from traversing
        # into its own StateDirectory. Force the 0700 source here; the
        # systemd.tmpfiles.rules fix below must still bring the ephemeral /var
        # back to 0755 (and the varprobe service, running as a NON-root user,
        # must be able to reach its persisted /var/lib dir).
        mkdir -p /sysroot/persist/var/lib
        chmod 0700 /sysroot/persist/var /sysroot/persist/var/lib
      '';
    };
  };

  # THE FIX under test (mirrors packages/hosts/beefcake/impermanence.nix):
  # tmpfiles-setup runs after local-fs (the binds are mounted) and before
  # services, so `d` re-asserts 0755 on the traversal parents every boot,
  # independent of the 0700 modes impermanence propagated from /persist.
  systemd.tmpfiles.rules = [
    "d /var 0755 root root -"
    "d /var/lib 0755 root root -"
    "d /var/cache 0755 root root -"
  ];

  # A non-root service whose persisted state dir it can only reach if /var and
  # /var/lib are traversable (0755). This is the beefcake failure mode in
  # miniature (knot/caddy/kanidm/… as their own users): with the fix it writes
  # its marker; without it, `install`/write fails "permission denied".
  users.groups.varprobe = { };
  users.users.varprobe = {
    isSystemUser = true;
    group = "varprobe";
  };
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/varprobe";
      user = "varprobe";
      group = "varprobe";
      mode = "0700";
    }
  ];
  systemd.services.varprobe = {
    description = "Write a marker into a persisted /var/lib dir as a non-root user";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "varprobe";
      Group = "varprobe";
      # Fails outright if the varprobe user cannot traverse /var -> /var/lib.
      ExecStart = "${pkgs.coreutils}/bin/touch /var/lib/varprobe/marker";
    };
  };

  # The failing surface from beefcake: dbus + NetworkManager + avahi. Without
  # the machine-id fix above, PID1's first-boot state makes dbus-broker's
  # launcher crash-loop (launcher_run_child: Permission denied) and NM never
  # comes up. With the fix, these must reach active and the system must
  # converge to multi-user.
  networking.networkmanager.enable = true;
  services.avahi.enable = true; # the netdev-group / dbus consumer from beefcake

  services.openssh = {
    enable = true;
    # Host identity persists even though / is wiped every boot.
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [ ./keys/demo-ssh-key.pub ];

  # Serial console for headless qemu debugging.
  boot.kernelParams = [ "console=ttyS0" ];

  services.getty.autologinUser = "root";
}
