{ pkgs, ... }:
{
  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.mongodb-7_0;
    # Don't open firewall globally - access via Tailscale or SSH tunnel
    openFirewall = false;
  };

  # Allow UniFi ports only on Tailscale interface
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      8443 # Web UI
      8080 # Device inform
    ];
    allowedUDPPorts = [
      3478 # STUN
    ];
  };
}
