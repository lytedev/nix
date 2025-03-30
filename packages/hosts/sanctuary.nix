{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "sanctuary-av";

  boot = {
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  imports = with hardware; [
    (diskoConfigurations.unencrypted { disk = "/dev/nvme0n1"; })
    common-cpu-amd
    common-gpu-amd
    common-pc-ssd
  ];

  powerManagement.cpuFreqGovernor = "performance";

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };

  # TODO: monitor mirroring
  # TODO: plasma or gnome dock?
  # TODO: lyricscreen service
  # TODO: audio management and recoring? is audacity sufficient? do we need drivers for the USB connection to the soundboard?
  # TODO: nixos tests?

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
