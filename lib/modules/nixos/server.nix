{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.server;
  hostname = config.networking.hostName;
in
{
  options.lyte.server = {
    enable = lib.mkEnableOption "Enable server-class host configuration (metrics, logs, always-on)";

    openobserveEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://openobserve.h.lyte.dev/api/default";
      description = "OpenObserve OTLP endpoint for metrics and logs.";
    };

    hostmetrics.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Collect host metrics (CPU, disk, filesystem, load, memory, network, paging, processes).";
    };

    nodeExporter.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable node_exporter with systemd unit metrics.";
    };

    logs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Collect and ship journald and file logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Servers should not suspend
    lyte.prevent-suspend.enable = lib.mkDefault true;

    # Sops secret for OpenObserve auth token (shared across servers)
    sops.secrets."openobserve-otel.env" = {
      sopsFile = lib.mkDefault ../../../secrets/servers/secrets.yml;
      group = "opentelemetry-collector";
      mode = "0440";
    };

    # User and group for OpenTelemetry Collector
    users.groups.opentelemetry-collector = { };
    users.users.opentelemetry-collector = {
      isSystemUser = true;
      group = "opentelemetry-collector";
      extraGroups = lib.optionals cfg.logs.enable [ "systemd-journal" ];
    };

    # Node exporter for systemd unit metrics
    services.prometheus.exporters.node = lib.mkIf cfg.nodeExporter.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      enabledCollectors = [ "systemd" ];
    };

    services.opentelemetry-collector = {
      enable = true;
      package = pkgs.opentelemetry-collector-contrib;

      settings = {
        receivers =
          lib.optionalAttrs cfg.hostmetrics.enable {
            hostmetrics = {
              collection_interval = "30s";
              scrapers = {
                cpu = { };
                disk = { };
                filesystem = { };
                load = { };
                memory = { };
                network = { };
                paging = { };
                process = {
                  mute_process_name_error = true;
                };
                processes = { };
              };
            };
          }
          // lib.optionalAttrs cfg.nodeExporter.enable {
            "prometheus/node" = {
              config = {
                scrape_configs = [
                  {
                    job_name = "node";
                    scrape_interval = "30s";
                    static_configs = [
                      {
                        targets = [
                          "${config.services.prometheus.exporters.node.listenAddress}:${toString config.services.prometheus.exporters.node.port}"
                        ];
                      }
                    ];
                  }
                ];
              };
            };
          }
          // lib.optionalAttrs cfg.logs.enable {
            journald = {
              directory = "/var/log/journal";
            };

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
          batch = {
            timeout = "5s";
            send_batch_size = 1024;
          };

          resource = {
            attributes = [
              {
                key = "host.name";
                value = hostname;
                action = "upsert";
              }
              {
                key = "service.name";
                value = "${hostname}-system";
                action = "upsert";
              }
            ];
          };

          resourcedetection = {
            detectors = [
              "system"
              "env"
            ];
            system = {
              hostname_sources = [ "os" ];
            };
          };
        };

        exporters = {
          "otlphttp/openobserve" = {
            endpoint = cfg.openobserveEndpoint;
            headers = {
              Authorization = "\${env:OPENOBSERVE_AUTH}";
              stream-name = "default";
            };
          };
        };

        service = {
          telemetry.metrics.level = "none";

          pipelines =
            let
              defaultProcessors = [
                "resourcedetection"
                "resource"
                "batch"
              ];
            in
            lib.optionalAttrs (cfg.hostmetrics.enable || cfg.nodeExporter.enable) {
              metrics = {
                receivers =
                  lib.optionals cfg.hostmetrics.enable [ "hostmetrics" ]
                  ++ lib.optionals cfg.nodeExporter.enable [ "prometheus/node" ];
                processors = defaultProcessors;
                exporters = [ "otlphttp/openobserve" ];
              };
            }
            // lib.optionalAttrs cfg.logs.enable {
              logs = {
                receivers = [
                  "journald"
                  "filelog"
                ];
                processors = defaultProcessors;
                exporters = [ "otlphttp/openobserve" ];
              };
            };
        };
      };
    };

    systemd.services.opentelemetry-collector.serviceConfig = {
      EnvironmentFile = config.sops.secrets."openobserve-otel.env".path;
      SupplementaryGroups = [ "opentelemetry-collector" ];
    };
  };
}
