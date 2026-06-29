{
  boot = {
    zfs.extraPools = [ "zstorage" ];
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    # kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "nohibernate" ];
    loader.systemd-boot.enable = true;
    # The ESP is only 512MB. Without a limit systemd-boot keeps every generation's
    # kernel+initrd until /boot fills and bootloader installs fail (which is exactly
    # what blocked the 26.05 upgrade). Cap retained generations to keep headroom.
    loader.systemd-boot.configurationLimit = 20;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/992ce55c-7507-4d6b-938c-45b7e891f395";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/B6C4-7CF4";
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
    # NOTE: /var/lib/containers and /var/lib/private were relocated onto zstorage
    # using ZFS-native mountpoints (mountpoint=/var/lib/..., like /storage) — done
    # imperatively 2026-06-29 via the runbook below. They are intentionally NOT
    # declared here: a fileSystems entry (legacy mountpoint) would conflict with
    # the live ZFS-native mounts. See issues/closed/beefcake-relocate-state-to-pool.md.
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
  };
}
