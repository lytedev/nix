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
{ ... }:
{
  disko.devices = {
    disk.main = {
      device = "/dev/vda"; # the slot zvol, presented as virtio-blk vda
      type = "disk";
      imageSize = "40G"; # root + /nix base closure + a little upper headroom
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
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          postCreateHook = "zfs snapshot rpool/local/root@blank";
        };
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.atime = "off";
        };
        "local/nix-upper" = {
          type = "zfs_fs";
          mountpoint = "/nix-upper";
          options.atime = "off";
        };
        "persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
        };
      };
    };
  };

  # The image-build VM imports the pool under a different hostid; force the
  # first import (real slots share the host's hostid, so this is build-only —
  # same as the overlay-boot/rollback prototypes).
  boot.zfs.forceImportRoot = true;
}
