{ config, pkgs, ... }:
{
  # Secrets for OpenObserve authentication
  sops.secrets."openobserve-otel.env" = {
    group = "opentelemetry-collector";
    mode = "0440";
  };

  # User and group for OpenTelemetry Collector
  users.groups.opentelemetry-collector = { };
  users.users.opentelemetry-collector = {
    isSystemUser = true;
    group = "opentelemetry-collector";
  };

  # Keep ZFS and PostgreSQL exporters for specialized metrics
  # OTel Collector will scrape them via prometheus receiver
  services.prometheus.exporters = {
    postgres = {
      enable = true;
      listenAddress = "127.0.0.1";
      runAsLocalSuperUser = true;
    };
    zfs = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
  };

  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;

    settings = {
      receivers = {
        # Collect host metrics (replaces node_exporter)
        hostmetrics = {
          collection_interval = "30s";
          scrapers = {
            cpu = {};
            disk = {};
            filesystem = {};
            load = {};
            memory = {};
            network = {};
            paging = {};
            process = {
              mute_process_name_error = true;
            };
            processes = {};
          };
        };

        # Scrape ZFS exporter
        "prometheus/zfs" = {
          config = {
            scrape_configs = [
              {
                job_name = "zfs";
                scrape_interval = "30s";
                static_configs = [
                  {
                    targets = [
                      "${config.services.prometheus.exporters.zfs.listenAddress}:${toString config.services.prometheus.exporters.zfs.port}"
                    ];
                  }
                ];
              }
            ];
          };
        };

        # Scrape PostgreSQL exporter
        "prometheus/postgres" = {
          config = {
            scrape_configs = [
              {
                job_name = "postgres";
                scrape_interval = "30s";
                static_configs = [
                  {
                    targets = [
                      "${config.services.prometheus.exporters.postgres.listenAddress}:${toString config.services.prometheus.exporters.postgres.port}"
                    ];
                  }
                ];
              }
            ];
          };
        };

        # Collect systemd journal logs (all units)
        journald = {
          directory = "/var/log/journal";
        };

        # Collect file logs
        filelog = {
          include = [ "/var/log/*.log" ];
          start_at = "end";
          operators = [
            {
              type = "regex_parser";
              regex = "^(?P<timestamp>[^ ]+) (?P<severity>[^ ]+) (?P<message>.*)$";
            }
          ];
        };
      };

      processors = {
        # Batch processing for efficiency
        batch = {
          timeout = "5s";
          send_batch_size = 1024;
        };

        # Add resource attributes
        resource = {
          attributes = [
            {
              key = "host.name";
              value = "beefcake";
              action = "upsert";
            }
            {
              key = "service.name";
              value = "beefcake-system";
              action = "upsert";
            }
          ];
        };

        # Detect resource information
        resourcedetection = {
          detectors = [ "system" "env" ];
          system = {
            hostname_sources = [ "os" ];
          };
        };
      };

      exporters = {
        # Send metrics to OpenObserve
        "otlphttp/metrics" = {
          endpoint = "http://127.0.0.1:5080/api/default";
          headers = {
            Authorization = "\${env:OPENOBSERVE_AUTH}";
            stream-name = "default";
          };
        };

        # Send logs to OpenObserve
        "otlphttp/logs" = {
          endpoint = "http://127.0.0.1:5080/api/default";
          headers = {
            Authorization = "\${env:OPENOBSERVE_AUTH}";
            stream-name = "default";
          };
        };

        # Prometheus exporter for OTel Collector's own metrics (avoid port conflict with atuin)
        prometheus = {
          endpoint = "0.0.0.0:8889";
          namespace = "otelcol";
        };
      };

      service = {
        # Disable internal telemetry to avoid port 8888 conflict with atuin
        # We export collector metrics via the prometheus exporter in the pipeline instead
        telemetry = {
          metrics = {
            level = "none";
          };
        };

        pipelines = {
          # Metrics pipeline
          metrics = {
            receivers = [ "hostmetrics" "prometheus/zfs" "prometheus/postgres" ];
            processors = [ "resourcedetection" "resource" "batch" ];
            exporters = [ "otlphttp/metrics" "prometheus" ];
          };

          # Logs pipeline
          logs = {
            receivers = [ "journald" "filelog" ];
            processors = [ "resourcedetection" "resource" "batch" ];
            exporters = [ "otlphttp/logs" ];
          };
        };
      };
    };
  };

  # Ensure OTel collector can read journal
  users.users.opentelemetry-collector.extraGroups = [ "systemd-journal" ];

  # Set environment variables from secrets
  systemd.services.opentelemetry-collector.serviceConfig = {
    EnvironmentFile = config.sops.secrets."openobserve-otel.env".path;
    SupplementaryGroups = [ "opentelemetry-collector" ];
  };
}
