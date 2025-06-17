{
  diskoConfigurations,
  hardware,
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

  boot.loader.systemd-boot.enable = true;

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

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-ocl
        intel-vaapi-driver
      ];
    };
    sensor.iio.enable = true; # auto-rotation in tablet mode
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  imports = with hardware; [
    (diskoConfigurations.standardWithHibernateSwap {
      disk = "/dev/nvme0n1";
      swapSize = "16G";
    })
    common-cpu-intel
    common-pc-ssd
  ];

  lyte.desktop.enable = true;
  lyte.laptop.enable = true;
  family-account.enable = true;
  home-manager.users.daniel = {
    lyte = {
      shell = {
        enable = true;
        learn-jujutsu-not-git.enable = true;
      };
      desktop.enable = true;
    };
    home = {
      stateVersion = "25.05";
    };
  };
}
