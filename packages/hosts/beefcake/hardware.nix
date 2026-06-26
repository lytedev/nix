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

    # Relocated off the single non-redundant boot disk onto the pool (see
    # issues/open/beefcake-relocate-state-to-pool.md). These datasets and their
    # data MUST already exist before this is deployed — the runbook creates them
    # (zfs create + rsync) first; otherwise an empty dataset mounts over live
    # state. Both use mountpoint=legacy so NixOS owns the mount + boot ordering
    # (local-fs.target, before podman / DynamicUser services), like /nix.
    "/var/lib/containers" = {
      device = "zstorage/containers";
      fsType = "zfs";
    };
    "/var/lib/private" = {
      device = "zstorage/varlib-private";
      fsType = "zfs";
    };
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
  };
}
