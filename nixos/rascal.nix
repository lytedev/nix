{
  inputs,
  config,
  modulesPath,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "ehci_pci" "usbhid" "uas" "sd_mod"];
  boot.kernelModules = ["kvm-amd"];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2e2ad73a-6264-4a7b-8439-9c05295d903d";
    fsType = "f2fs";
  };

  fileSystems."/storage" = {
    device = "/dev/disk/by-uuid/410fa651-4918-447c-9337-97cc12ff6d2a";
    fsType = "ext4";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  users.users = {
    beefcake = {
      # used for restic backups
      isNormalUser = true;
      openssh.authorizedKeys.keys =
        config.users.users.daniel.openssh.authorizedKeys.keys
        ++ [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7HrojwoyHED+A/FzRjYmIL0hzofwBd9IYHH6yV0oPO root@beefcake"
        ];
    };

    daniel = {
      # used for restic backups
      isNormalUser = true;
      extraGroups = ["users" "wheel" "video" "dialout" "uucp"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
    };

    root = {
      openssh.authorizedKeys.keys = config.users.users.daniel.openssh.authorizedKeys.keys;
    };
  };

  networking = {
    hostName = "rascal";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22];
    };
  };

  system.stateVersion = "22.05";
}
