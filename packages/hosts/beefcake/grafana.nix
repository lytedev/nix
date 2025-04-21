{ config, ... }:
{
  # grafana
  systemd.tmpfiles.settings = {
    "10-grafana" = {
      "/storage/grafana" = {
        "d" = {
          mode = "0750";
          user = "grafana";
          group = "grafana";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/grafana"
  ];
  sops.secrets = {
    grafana-admin-password = {
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };
    grafana-smtp-password = {
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };
  };
  services.grafana = {
    enable = true;
    dataDir = "/storage/grafana";
    provision = {
      enable = true;
      datasources = {
        settings = {
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:${toString config.services.prometheus.port}";
              isDefault = true;
            }
          ];
        };
      };
    };
    settings = {
      server = {
        http_port = 3814;
        root_url = "https://grafana.h.lyte.dev";
      };
      smtp = {
        enabled = true;
        from_address = "grafana@lyte.dev";
        user = "grafana@lyte.dev";
        host = "smtp.mailgun.org:587";
        password = ''$__file{${config.sops.secrets.grafana-smtp-password.path}}'';
      };
      security = {
        admin_email = "daniel@lyte.dev";
        admin_user = "lytedev";
        admin_file = ''$__file{${config.sops.secrets.grafana-admin-password.path}}'';
      };
      # database = {
      # };
    };
  };
  networking.firewall.allowedTCPPorts = [
    9000
  ];
  services.caddy.virtualHosts."grafana.h.lyte.dev" = {
    extraConfig = ''reverse_proxy :${toString config.services.grafana.settings.server.http_port}'';
  };
}
