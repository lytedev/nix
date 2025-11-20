{ config, ... }:
{
  # Secrets for OpenObserve authentication
  sops.secrets = {
    "openobserve-promtail.env" = {
      owner = "promtail";
      mode = "0400";
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };

      # Send logs to OpenObserve's Loki-compatible endpoint
      clients = [
        {
          url = "http://127.0.0.1:5080/api/default/loki/api/v1/push";
          basic_auth = {
            username = "daniel@lyte.dev";
            password_file = config.sops.secrets."openobserve-promtail.env".path;
          };
        }
      ];

      positions = {
        filename = "/var/lib/promtail/positions.yaml";
      };

      scrape_configs = [
        # Collect systemd journal logs
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "beefcake";
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "hostname";
            }
            {
              source_labels = [ "__journal_priority" ];
              target_label = "priority";
            }
            {
              source_labels = [ "__journal_syslog_identifier" ];
              target_label = "syslog_identifier";
            }
          ];
        }

        # Collect logs from common log directories
        {
          job_name = "system";
          static_configs = [
            {
              targets = [ "localhost" ];
              labels = {
                job = "varlogs";
                host = "beefcake";
                __path__ = "/var/log/*.log";
              };
            }
          ];
        }
      ];
    };
  };

  # Ensure promtail can read systemd journal
  users.users.promtail.extraGroups = [ "systemd-journal" ];
}
