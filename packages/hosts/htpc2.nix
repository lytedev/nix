{
  hardware,
  config,
  diskoConfigurations,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "htpc";

  boot = {
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [
        "8821au"
        "8812au"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = with config.boot.kernelPackages; [
      rtl8812au
      rtl8821au
    ];
  };

  imports = with hardware; [
    (diskoConfigurations.unencrypted {
      disk = "/dev/nvme0n1";
      name = "htpc";
    })
    common-cpu-intel
    common-pc-ssd
  ];

  prevent-suspend.enable = true;

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };

  networking.wifi.enable = true;
  lyte.desktop.enable = true;
  lyte.shell.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  lyte.family-account.enable = true;
}
