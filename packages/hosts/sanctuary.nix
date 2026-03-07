{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "sanctuary-av";

  boot = {
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

  lyte = {
    desktop.enable = true;
    gpu = "amd";
    family-account.enable = true;
  };
}
