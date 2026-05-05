{
  pkgs,
  lib,
  config,
  ...
}:
{
  system.stateVersion = "25.05";
  networking = {
    hostName = "flipflop2";
    wifi.enable = true;
  };

  services.fprintd = {
    # TODO: am I missing a driver? see arch wiki for this h/w
    enable = false;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  environment.systemPackages =
    #with pkgs;
    [ ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "acpi_call"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  hardware.bluetooth.powerOnBoot = false;

  hardwareModules = [
    "common-cpu-intel"
    "common-pc-ssd"
  ];
  diskConfig = {
    name = "standardWithHibernateSwap";
    params = {
      disk = "/dev/nvme0n1";
      swapSize = "16G";
    };
  };

  # Steam: install via flatpak (com.valvesoftware.Steam).

  lyte = {
    two-in-one.enable = true;
    gpu = "intel";
    family-account.enable = true;
  };
}
