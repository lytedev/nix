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
    hostName = "babyflip";
    wifi.enable = true;
  };

  boot.loader.systemd-boot.enable = true;

  /*
    systemd.services.activate-touch-hack = {
      enable = true;
      description = "Touch wake Thinkpad X1 Yoga 3rd gen hack";

      unitConfig = {
        After = [
          "suspend.target"
          "hibernate.target"
          "hybrid-sleep.target"
          "suspend-then-hibernate.target"
        ];
      };

      serviceConfig = {
        ExecStart = ''
          /bin/sh -c "echo '\\_SB.PCI0.LPCB.EC._Q2A' > /proc/acpi/call"
        '';
      };

      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
    };
  */

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
  ];
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
    powerOnBoot = true;
  };

  imports = with hardware; [
    diskoConfigurations.babyflip
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
    home.stateVersion = "24.11";
  };
}
