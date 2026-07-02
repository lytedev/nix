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
          mountpoint = "/persist";
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;

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
  };

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
