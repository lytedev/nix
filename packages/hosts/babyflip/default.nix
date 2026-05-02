{
  system.stateVersion = "25.05";
  networking.hostName = "babyflip";
  diskConfig = "babyflip";
  hardwareModules = [
    "common-cpu-intel"
    "common-pc-ssd"
  ];

  imports = [
    ./touchscreen-resume.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "mem_sleep_default=deep" ];
  };

  hardware.bluetooth.powerOnBoot = true;

  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    two-in-one.enable = true;
    gpu = "intel";
    family-account.enable = true;
    desktop.niri.osk = "wvkbd";
  };
}
