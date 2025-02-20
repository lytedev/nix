{ ... }:
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

  services.tailscale.useRoutingFeatures = "server";

  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };
}
