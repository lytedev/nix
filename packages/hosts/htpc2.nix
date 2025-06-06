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
  home-manager.users.daniel = {
    lyte.shell.enable = true;
    lyte.desktop.enable = true;
  };

  family-account.enable = true;
  home-manager.users.flanfam = {
    lyte.shell.enable = true;
    lyte.desktop.enable = true;
  };
}
