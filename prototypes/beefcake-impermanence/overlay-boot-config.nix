# P-overlay Milestone 2 (Phase 3): boot a NixOS system whose real /nix/store is
# an OverlayFS — RO lower = the base closure, RW upper = a per-slot delta — and
# prove it RUNS + accepts new store paths into the upper. This is the guest
# /nix strategy (design open-Q#4 resolution) validated at boot, folded into the
# guest-representative prototype per Daniel (no standalone throwaway).
#
# M1 (overlay-nix-test) proved Nix's store-DB layering in isolation. M2 proves
# the harder half: a running system whose store IS the overlay.
#
# Approach (the deliberate simplification vs a local-overlay:// system store):
#   - /nix is a normal ZFS dataset (base closure at /nix/store, DB at
#     /nix/var/nix/db — the DB already knows the base paths from install). Kept
#     ZFS-native (mountpoint=/nix), the pattern proven to actually receive the
#     closure at install (a legacy /nix comes up EMPTY — the closure lands on
#     the root instead).
#   - EARLY STAGE-2 (after zfs-mount, before nix-daemon) we overlay ONLY
#     /nix/store: lowerdir = the base store captured via a bind (so the mount
#     doesn't eat its own lower), upperdir = a separate persistent dataset (the
#     slot delta). Not initrd: a ZFS-native /nix isn't a stage-1 mount, and the
#     overlay is transparent to already-running processes (lower == same files).
#   - The default local store then Just Works: reads fall through to the lower,
#     new builds write files to the upper and register in the (writable) DB.
#   - Root is impermanent (@blank) like the guest; /nix + the upper persist.
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
  networking.hostName = "overlay-boot-proto";
  networking.hostId = "0ec1a900";

  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;
  documentation.enable = false;

  disko.devices = {
    disk.main = {
      device = "/dev/vda";
      type = "disk";
      imageSize = "8G"; # room for base store + upper
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
          postCreateHook = "zfs snapshot rpool/local/root@blank";
        };
        # Base store (LOWER) + the nix DB. ZFS-native /nix — the pattern that
        # actually receives the closure at install (persists; NOT rolled back).
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.atime = "off";
        };
        # The writable UPPER (per-slot delta) + overlay workdir. Persists across
        # the root wipe.
        "local/nix-upper" = {
          type = "zfs_fs";
          mountpoint = "/nix-upper";
          options.atime = "off";
        };
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
        };
      };
    };
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    initrd.systemd.enable = true;
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = true;
    zfs.devNodes = "/dev/disk/by-path";
    kernelParams = [ "console=ttyS0" ];
    kernelModules = [ "overlay" ]; # for the stage-2 overlay-nix-store unit

    # Impermanent root (@blank) — the guest is impermanent too. Stage-1, before
    # the root mounts; /nix and the upper are separate persistent datasets.
    initrd.systemd.services.rollback-root = {
      description = "Rollback rpool/local/root to @blank (impermanence)";
      wantedBy = [ "initrd.target" ];
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

  # THE MECHANISM UNDER TEST: make /nix/store an OverlayFS in EARLY stage-2,
  # after the ZFS datasets mount and before nix-daemon (so nix writes land in
  # the upper). Transparent to the already-running init (lower == same files).
  systemd.services.overlay-nix-store = {
    description = "Overlay /nix/store (RO base lower + RW upper)";
    wantedBy = [ "multi-user.target" ];
    # ZFS-native /nix and /nix-upper are mounted by zfs-mount.service (NOT
    # .mount units), so RequiresMountsFor can't order against them — it depends
    # on a nix.mount that never exists and the unit gets silently dropped.
    # Order after the ZFS mounts + local-fs, before nix-daemon (so nix writes
    # land in the upper). Normal default deps (a DefaultDependencies=false
    # sysinit cycle also dropped it).
    after = [
      "zfs-mount.service"
      "local-fs.target"
    ];
    requires = [ "zfs-mount.service" ];
    # NOT before nix-daemon.socket — the socket is pulled into sockets.target
    # (before basic.target), so ordering before it creates a cycle systemd
    # breaks by deleting sockets.target. Before the daemon SERVICE suffices.
    before = [ "nix-daemon.service" ];
    path = [ pkgs.util-linux ]; # mount / findmnt
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euxo pipefail
      # Idempotent: skip if /nix/store is already an overlay (e.g. re-run).
      if findmnt -n -o FSTYPE /nix/store | grep -qx overlay; then
        echo "overlay-nix-store: already overlaid"; exit 0
      fi
      # Capture the base store as the overlay LOWER via a bind — otherwise
      # mounting the overlay AT /nix/store would shadow its own lower.
      mkdir -p /nix/.store-lower /nix-upper/store /nix-upper/work
      mount --bind /nix/store /nix/.store-lower
      mount -t overlay overlay \
        -o lowerdir=/nix/.store-lower,upperdir=/nix-upper/store,workdir=/nix-upper/work \
        /nix/store
      echo "overlaid /nix/store (lower=base, upper=nix-upper)"
    '';
  };

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./keys/demo-ssh-key.pub ];
  services.getty.autologinUser = "root";
  networking.networkmanager.enable = true;
}
