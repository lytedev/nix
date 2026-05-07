{ pkgs, ... }:
{
  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.mongodb-7_0;
    # Don't open firewall globally - access via Tailscale or SSH tunnel
    openFirewall = false;
  };

  # Unifi's Java app routinely takes >90s to start under load; the default
  # systemd timeout kills it mid-init and deploys roll back. Give it room.
  systemd.services.unifi.serviceConfig.TimeoutStartSec = "5min";

  # Web UI on Tailscale only (admin access).
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      8443 # Web UI
      8080 # Device inform (also exposed on LAN below)
    ];
    allowedUDPPorts = [
      3478 # STUN
    ];
  };

  # Device inform must be reachable from APs on the LAN.
  networking.firewall.interfaces."eno1" = {
    allowedTCPPorts = [
      8080 # Device inform
    ];
    allowedUDPPorts = [
      10001 # AP discovery (controller broadcasts here)
    ];
  };
}
