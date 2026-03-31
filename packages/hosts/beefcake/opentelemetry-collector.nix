{ config, ... }:
{
  # beefcake-specific: override sops to use per-host secrets file
  sops.secrets."openobserve-otel.env" = {
    sopsFile = ../../../secrets/beefcake/secrets.yml;
  };

  # beefcake-specific: OpenObserve runs locally, use localhost
  lyte.server.openobserveEndpoint = "http://127.0.0.1:5080/api/default";

  # beefcake-specific exporters: postgres, zfs
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

  # beefcake-specific: add postgres/zfs scrapers and self-metrics exporter
  services.opentelemetry-collector.settings = {
    receivers = {
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
    };

    exporters = {
      prometheus = {
        endpoint = "0.0.0.0:8889";
        namespace = "otelcol";
      };
    };

    service.pipelines.metrics = {
      receivers = [
        "prometheus/zfs"
        "prometheus/postgres"
      ];
      exporters = [ "prometheus" ];
    };
  };
}
