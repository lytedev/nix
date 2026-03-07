{
  system.stateVersion = "24.11";
  networking.hostName = "thinker";
  diskConfig = "thinker";
  hardwareModules = [
    "lenovo-thinkpad-t480"
    "common-pc-laptop-ssd"
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
  ];

  lyte.editableConfigFiles = true;
  lyte.flakePath = "/etc/nix/flake";
  lyte.laptop.enable = true;
}
