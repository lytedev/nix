{
  diskoConfigurations,
  hardware,
  pkgs,
  ...
}:
{
  system.stateVersion = "25.05";
  networking = {
    hostName = "flab";
    wifi.enable = true;
  };

  boot.loader.systemd-boot.enable = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
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
    framework-12-13th-gen-intel
    diskoConfigurations.babyflip
    common-cpu-intel
    common-pc-ssd
  ];

  services.tlp.enable = false;

  services.tuned = {
    enable = true;
  };

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
