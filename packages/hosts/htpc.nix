{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "htpc";

  boot = {
    loader = {
      grub = {
        enable = true;
        device = "/dev/sda";
        useOSProber = true;
      };
    };

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
    extraModulePackages = [
      # pkgs.rtl8811au
      config.boot.kernelPackages.rtl8812au
      config.boot.kernelPackages.rtl8821au
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/86d8ded0-1c6f-4a79-901c-2d59c11b5ca8";
    fsType = "ext4";
  };

  imports = with hardware; [
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
}
