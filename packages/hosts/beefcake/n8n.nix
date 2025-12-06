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

    # Configuration via environment variables
    # See https://docs.n8n.io/hosting/environment-variables/ for all options
    environment = {
      WEBHOOK_URL = "https://n8n.h.lyte.dev/";
      N8N_HOST = "n8n.h.lyte.dev";
      N8N_PORT = "5678";
      N8N_PROTOCOL = "https";
    };
  };

  # Expose web UI via Caddy
  services.caddy.virtualHosts."n8n.h.lyte.dev" = {
    extraConfig = ''reverse_proxy :5678'';
  };
}
