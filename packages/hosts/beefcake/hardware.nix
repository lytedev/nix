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
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
  };
}
