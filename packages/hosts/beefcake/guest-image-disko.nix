# beefcake-guest-image: the disko layout for a slot's OS disk (Phase 3/4 cutover
# tooling — runbook Part 1 step 2). Applied via
# `beefcake-guest.extendModules { modules = [ disko + this ]; }` to produce a
# bootable image (system.build.diskoImagesScript) that is written to a slot's
# zvol (/dev/zvol/rpool/beefcake-{blue,green}). This is what removes the last
# "provision via nixos-install by hand" TODO from the cutover.
#
# The layout mirrors overlay-boot-config (the proven M2) + beefcake's
# impermanence/guest-hardware fileSystems:
#   rpool/local/root  (mountpoint / , @blank — impermanent, wiped each boot)
#   rpool/local/nix   (the /nix base closure = the overlay LOWER)
#   rpool/local/nix-upper (the per-slot RW overlay upper — empty at install)
#   rpool/persist     (durable state; = beefcake impermanence.nix's /persist)
#   ESP (label ESP — guest-hardware.nix mounts /boot by-label/ESP)
# zstorage is NOT here — the host shares it via virtiofs.
{ lib, ... }:
{
  # Bug #13 (found live at cutover): disko's config generation MERGES its own
  # fileSystems entries (with options=[zfsutil]) into the guest's non-mkForce'd
  # ones (/nix-upper, /persist) — and zfsutil mounts FAIL on legacy datasets
  # (while the mkForce'd plain-mount entries fail on NATIVE datasets). One
  # source of truth: the guest config's fileSystems; disko only partitions.
  disko.enableConfig = false;
  # The flake-registry/NIX_PATH pins embed the ENTIRE nixpkgs source tree
  # (~100k tiny files) in the closure; copying that through virtiofs blows the
  # image-build VM's system fd limit ("Too many open files in system" -> init
  # dies -> kernel panic). The exact gotcha the prototypes encode
  # (rollback-config.nix) — prune the pins in the IMAGE variant only. The
  # deployed guest re-adds the registry pin on its first activation (lands in
  # the overlay upper; a cached ~250MB fetch — harmless).
  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;
  nix.registry = lib.mkForce { };
  nix.nixPath = lib.mkForce [ ];

  disko.devices = {
    disk.main = {
      device = "/dev/vda"; # the slot zvol, presented as virtio-blk vda
      type = "disk";
      # Root + /nix base closure + /nix-upper headroom + the guest's /persist
      # (the non-cache persist set, ~15G, rsynced in at the window; restic
      # caches are deliberately NOT migrated — they rebuild). The .raw is
      # SPARSE and streams compressed; the slot zvol is created sparse (-s).
      # NOTE the guest pool is ALSO named "rpool" (impermanence.nix hardcodes
      # rpool/* paths): structurally safe at boot (the host's own rpool imports
      # in initrd BEFORE any zvol device exists), but NEVER `zpool import`/
      # `zpool import -a` by scan on the host — use the pool GUID + `-t` for
      # any maintenance import of a slot pool.
      imageSize = "100G";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              extraArgs = [
                "-n"
                "ESP"
              ]; # label ESP -> guest-hardware /boot by-label/ESP
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
        # ALL datasets legacy-at-creation: matches live beefcake's proven layout
        # and the guest's plain-mount fileSystems (bug #13's other half; the
        # disko-native mountpoints + property flipping was the live workaround).
        "local/root" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          postCreateHook = "zfs snapshot rpool/local/root@blank";
        };
        "local/nix" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          options.atime = "off";
        };
        "local/nix-upper" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          options.atime = "off";
        };
        "persist" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
        };
      };
    };
  };

  # The image-build VM imports the pool under a different hostid; force the
  # first import (real slots share the host's hostid, so this is build-only —
  # same as the overlay-boot/rollback prototypes).
  boot.zfs.forceImportRoot = true;
}
