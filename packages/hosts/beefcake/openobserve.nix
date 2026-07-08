{ config, ... }:
{
  # User and group for OpenObserve
  users.groups.openobserve = { };
  users.users.openobserve = {
    isSystemUser = true;
    createHome = false;
    home = "/storage/openobserve";
    group = "openobserve";
    linger = true;
  };

  # Storage setup
  systemd.tmpfiles.settings = {
    "10-openobserve" = {
      "/storage/openobserve/data" = {
        "d" = {
          mode = "0770";
          user = "openobserve";
          group = "openobserve";
        };
      };
    };
  };

  # Backup integration
  # Back up ONLY OpenObserve's metadata (dashboards, users, alerts, functions,
  # stream schemas — all in data/db/metadata.sqlite, ~1.8G), NOT the ingested
  # log/metric data under data/{stream,wal,cache,tmp} (~297G / 15M tiny files).
  # That data is regenerable observability history; backing it up made restic
  # take 6+h and bloated every repo. See the 2026-07 disk-overhaul thread.
  services.restic.commonPaths = [ "/storage/openobserve/data/db" ];

  # Secrets for OpenObserve authentication
  sops.secrets = {
    "openobserve.env" = {
      owner = "openobserve";
      group = "openobserve";
      mode = "0400";
    };
  };

  # OpenObserve container
  virtualisation.oci-containers.containers.openobserve = {
    autoStart = true;
    image = "public.ecr.aws/zinclabs/openobserve:v0.70.2";
    extraOptions = [
      "--pull=newer"
    ];
    environmentFiles = [
      config.sops.secrets."openobserve.env".path
    ];
    environment = {
      ZO_DATA_DIR = "/data";
      ZO_ROOT_USER_EMAIL = "daniel@lyte.dev";
      # Use localhost since we'll reverse proxy through Caddy
      ZO_HTTP_ADDR = "0.0.0.0";
      ZO_HTTP_PORT = "5080";
      # Optional: Set time zone
      TZ = "America/Chicago";
      # Enable all features
      ZO_BASE_URI = "";
      ZO_NODE_ROLE = "all";
    };
    ports = [ "127.0.0.1:5080:5080" ];
    volumes = [
      "/storage/openobserve/data:/data"
    ];
  };

  # Reverse proxy through Caddy
  services.caddy.virtualHosts."openobserve.h.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :5080
    '';
  };

  # No external firewall ports needed - only accessible via Caddy reverse proxy
}
