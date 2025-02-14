{
  pkgs,
  config,
  lib,
  ...
}: {
  networking.hostName = "htpc";

  networking.networkmanager.enable = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = ["8821au" "8812au"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [
    # pkgs.rtl8811au
    config.boot.kernelPackages.rtl8812au
    config.boot.kernelPackages.rtl8821au
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/86d8ded0-1c6f-4a79-901c-2d59c11b5ca8";
    fsType = "ext4";
  };

  swapDevices = [];

  hardware.bluetooth = {
    enable = true;
    # package = pkgs.bluez;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
