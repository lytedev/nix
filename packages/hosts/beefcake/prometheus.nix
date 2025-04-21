{ config, ... }:
{
  services.prometheus = {
    enable = true;
    checkConfig = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    scrapeConfigs = [
      {
        job_name = "beefcake";
        static_configs = [
          {
            targets =
              let
                inherit (config.services.prometheus.exporters.node) port listenAddress;
              in
              [ "${listenAddress}:${toString port}" ];
          }
          {
            targets =
              let
                inherit (config.services.prometheus.exporters.zfs) port listenAddress;
              in
              [ "${listenAddress}:${toString port}" ];
          }
          {
            targets =
              let
                inherit (config.services.prometheus.exporters.postgres) port listenAddress;
              in
              [ "${listenAddress}:${toString port}" ];
          }
        ];
      }
    ];
    exporters = {
      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        runAsLocalSuperUser = true;
      };
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "systemd"
        ];
      };
      zfs = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
    };
  };
  /*
    TODO: promtail?
    idrac exporter?
    restic exporter?
    smartctl exporter?
    systemd exporter?
    NOTE: we probably don't want this exposed
    services.caddy.virtualHosts."prometheus.h.lyte.dev" = {
      extraConfig = ''reverse_proxy :${toString config.services.prometheus.port}'';
    };
  */
}
