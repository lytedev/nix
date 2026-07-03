{ ... }:
{
  users.groups.hearth = { };
  users.users.hearth = {
    isSystemUser = true;
    group = "hearth";
  };

  systemd.tmpfiles.settings."10-hearth" = {
    "/var/lib/hearth"."d" = {
      mode = "0750";
      user = "hearth";
      group = "hearth";
    };
  };

  virtualisation.oci-containers.containers.hearth = {
    image = "localhost/hearth:latest";
    autoStart = true;
    ports = [ "127.0.0.1:8473:8473" ];
    volumes = [ "/var/lib/hearth:/var/lib/hearth" ];
    # hearth.env is pushed to /var/lib/hearth/hearth.env by the deploy script
    environmentFiles = [ "/var/lib/hearth/hearth.env" ];
    environment = {
      LEPTOS_SITE_ROOT = "/app/site";
      LEPTOS_SITE_ADDR = "0.0.0.0:8473";
      LEPTOS_OUTPUT_NAME = "hearth";
      LEPTOS_SITE_PKG_DIR = "pkg";
      DATABASE_URL = "sqlite:/var/lib/hearth/hearth.db";
      # Hearth's HA base URL for the /music transport controls + timer announce.
      # The runtime hearth.env (pushed by Hearth's own deploy) still carries the
      # stale HA_URL=http://192.168.0.198:8123 — the DEAD bigtower address (HA
      # moved to beefcake). Pin the live Caddy URL here: podman `--env` overrides
      # `--env-file` for the same key (verified empirically), so this wins over
      # hearth.env and survives a Hearth redeploy / DB reset. The bridge-networked
      # container reaches HA via Caddy (raw :8124 is firewalled; localhost can't
      # work from the bridge net). NOW_PLAYING_HA_BASE pins the now-playing media
      # base to the same host. Token in hearth.env already works against beefcake
      # HA over Caddy (HTTP 200), so only the URL was wrong.
      HA_URL = "https://home-assistant.h.lyte.dev";
      NOW_PLAYING_HA_BASE = "https://home-assistant.h.lyte.dev";
    };
  };

  services.caddy.virtualHosts."hearth.h.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :8473
    '';
  };

  # sqlite DB + env; the container is rebuildable but this state is not.
  services.restic.commonPaths = [ "/var/lib/hearth" ];
}
