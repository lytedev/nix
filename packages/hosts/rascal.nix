{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.05";
  networking.hostName = "rascal";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "ehci_pci"
    "usbhid"
    "uas"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

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

  imports = with hardware; [
    common-cpu-amd
    common-pc-ssd
  ];

  users.groups.beefcake = { };
  users.groups.sftponly = { };
  users.users = {
    beefcake = {
      isSystemUser = true;
      home = "/storage/backups/beefcake";
      group = "beefcake";
      extraGroups = [ "sftponly" ];
      openssh.authorizedKeys.keys = config.lyte.userSshKeys ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7HrojwoyHED+A/FzRjYmIL0hzofwBd9IYHH6yV0oPO root@beefcake"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOEI82VdbyR1RYqSnFtlffHBtHFdXO0v9RmQH7GkfXo restic@beefcake"
      ];
    };
  };

  # ChrootDirectory requires the chroot dir to be root-owned and not writable by
  # others. The writable repo/ subdirectory is where restic actually stores data.
  systemd.tmpfiles.settings."10-backups-beefcake" = {
    "/storage/backups/beefcake" = {
      "d" = {
        mode = "0755";
        user = "root";
        group = "root";
      };
    };
    "/storage/backups/beefcake/repo" = {
      "d" = {
        mode = "0750";
        user = "beefcake";
        group = "beefcake";
      };
    };
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory /storage/backups/%u
      ForceCommand internal-sftp
      AllowTcpForwarding no
  '';

  networking = {
    useDHCP = true;
    wifi.enable = false;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-exit-node"
      "--accept-routes"
    ];
  };

  lyte.server.enable = true;
  lyte.headscale.usePreAuthKey = true;
  lyte.shell.enable = false;
}
