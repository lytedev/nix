{ diskoConfigurations, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "lyte-generic-headless";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    wifi.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  imports = [
    (diskoConfigurations.standardEncrypted { disk = "/dev/nvme0n1"; })
  ];

  services.tailscale.useRoutingFeatures = "server";

  lyte.shell.enable = true;
  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };
}
