{
  outputs,
  config,
  modulesPath,
  ...
}: {
  imports = [
    outputs.nixosModules.amd
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "ehci_pci" "usbhid" "uas" "sd_mod"];
  boot.kernelModules = ["kvm-amd"];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2e2ad73a-6264-4a7b-8439-9c05295d903d";
    fsType = "f2fs";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    hostName = "rascal";
    networkmanager.enable = true;
  };

  users.users.beefcake = {
    # used for restic backups
    isNormalUser = true;
    openssh.authorizedKeys.keys =
      config.users.users.daniel.openssh.authorizedKeys.keys
      ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7HrojwoyHED+A/FzRjYmIL0hzofwBd9IYHH6yV0oPO root@beefcake"
      ];
  };

  system.stateVersion = "22.05";
}
