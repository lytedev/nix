{
  config,
  modulesPath,
  ...
}: {
  imports = [
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

  users.groups.beefcake = {};
  users.users = {
    beefcake = {
      isSystemUser = true;
      createHome = true;
      home = "/storage/backups/beefcake";
      group = "beefcake";
      extraGroups = ["sftponly"];
      openssh.authorizedKeys.keys =
        config.users.users.daniel.openssh.authorizedKeys.keys
        ++ [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7HrojwoyHED+A/FzRjYmIL0hzofwBd9IYHH6yV0oPO root@beefcake"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOEI82VdbyR1RYqSnFtlffHBtHFdXO0v9RmQH7GkfXo restic@beefcake"
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

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory /storage/backups/%u
      ForceCommand internal-sftp
      AllowTcpForwarding no
  '';

  networking = {
    hostName = "rascal";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22];
    };
  };

  services.tailscale.useRoutingFeatures = "server";

  system.stateVersion = "24.05";
}
