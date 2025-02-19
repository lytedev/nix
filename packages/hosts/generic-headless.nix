{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.05";
  networking.hostName = "lyte-generic-headless";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "ehci_pci"
    "usbhid"
    "uas"
    "sd_mod"
  ];

  imports = with hardware; [
    common-cpu-amd
    common-pc-ssd
  ];

  users.groups.beefcake = { };
  users.users = {
    beefcake = {
      isSystemUser = true;
      createHome = true;
      home = "/storage/backups/beefcake";
      group = "beefcake";
      extraGroups = [ "sftponly" ];
      openssh.authorizedKeys.keys = config.users.users.daniel.openssh.authorizedKeys.keys ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7HrojwoyHED+A/FzRjYmIL0hzofwBd9IYHH6yV0oPO root@beefcake"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOEI82VdbyR1RYqSnFtlffHBtHFdXO0v9RmQH7GkfXo restic@beefcake"
      ];
    };
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory /storage/backups/%u
      ForceCommand internal-sftp
      AllowTcpForwarding no
  '';

  networking = {
    wifi.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  services.tailscale.useRoutingFeatures = "server";

  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };
}
