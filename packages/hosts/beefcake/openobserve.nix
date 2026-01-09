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
  services.restic.commonPaths = [ "/storage/openobserve" ];

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
    image = "public.ecr.aws/zinclabs/openobserve:v0.40.4";
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
