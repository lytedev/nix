{
  diskoConfigurations,
  hardware,
  pkgs,
  ...
}:
{
  system.stateVersion = "25.05";
  networking = {
    hostName = "babyflip";
    wifi.enable = true;
  };

  boot.loader.systemd-boot.enable = true;

  # Fix ELAN touchscreen not working after resume from suspend
  systemd.services.fix-touchscreen-resume = {
    description = "Rebind ELAN touchscreen after resume";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo i2c-ELAN901C:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind; sleep 0.5; echo i2c-ELAN901C:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind'";
    };
  };

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
  lyte.shell.enable = true;
}
