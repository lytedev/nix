{ config, ... }:

{
  # Add n8n data to backup paths
  services.restic.commonPaths = [
    "/var/lib/n8n"
  ];

  # Enable n8n service
  services.n8n = {
    enable = true;
    openFirewall = false; # Don't open firewall ports by default

    # Webhook URL for reverse proxy setup
    webhookUrl = "https://n8n.h.lyte.dev/";

    # Configuration settings for n8n
    # See https://docs.n8n.io/hosting/environment-variables/ for all options
    settings = {
      host = "n8n.h.lyte.dev";
      port = 5678;
      protocol = "https";
    };
  };

  # Expose web UI via Caddy
  services.caddy.virtualHosts."n8n.h.lyte.dev" = {
    extraConfig = ''reverse_proxy :5678'';
  };
}
