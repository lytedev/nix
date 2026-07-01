# Root-on-ZFS boot config (SSD mirror). STAGED — do NOT deploy until the rpool +
# ESPs exist (Phase 1 of issues/open/beefcake-root-on-zfs-mirror.md); deploying
# this before rpool/root exists makes the system unbootable.
{ pkgs, ... }:
{
  boot = {
    # zstorage holds /nix + the ZFS-native mounts (/storage, /var/lib/{containers,
    # private}); extraPools imports it and runs `zfs mount -a` for those. rpool
    # (the root pool) is auto-imported in initrd because / is on it.
    zfs.extraPools = [ "zstorage" ];
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "nohibernate" ];
    loader.systemd-boot.enable = true;
    # ESP is now ~1G per SSD, so 20 generations is comfortable.
    loader.systemd-boot.configurationLimit = 20;
    loader.efi.canTouchEfiVariables = true;
    # Boot redundancy: /boot is SSD-A's ESP. After systemd-boot installs, mirror
    # the whole ESP onto SSD-B's ESP so either SSD boots (via each ESP's fallback
    # \EFI\BOOT\BOOTX64.EFI) if the other dies. Skips cleanly while SSD-B's ESP
    # doesn't exist yet (Phase 1 = single SSD).
    loader.systemd-boot.extraInstallCommands = ''
      espB=/dev/disk/by-partlabel/ESP-B
      if [ -e "$espB" ]; then
        m=$(mktemp -d)
        ${pkgs.util-linux}/bin/mount "$espB" "$m"
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ "$m"/
        ${pkgs.util-linux}/bin/umount "$m"
        rmdir "$m"
      fi
    '';
  };

  fileSystems = {
    # Root on the SSD ZFS mirror. /nix stays on zstorage (608G — too big for the
    # SSDs). Both pools are imported in initrd (zstorage already was, for /nix).
    "/" = {
      device = "rpool/root";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP-A";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    "/nix" = {
      device = "zstorage/nix";
      fsType = "zfs";
    };
    # /var/lib/containers and /var/lib/private are ZFS-native mounts on zstorage
    # (mountpoint=/var/lib/..., like /storage), created imperatively 2026-06-29 —
    # intentionally NOT declared here. See issues/closed/beefcake-relocate-state-to-pool.md.
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
  };
}
