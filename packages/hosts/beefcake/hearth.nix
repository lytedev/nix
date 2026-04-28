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
    # hearth.env is pushed to /var/lib/hearth/hearth.env by the deploy script
    environmentFiles = [ "/var/lib/hearth/hearth.env" ];
    environment = {
      LEPTOS_SITE_ROOT = "/app/site";
      LEPTOS_SITE_ADDR = "0.0.0.0:8473";
      LEPTOS_OUTPUT_NAME = "hearth";
      LEPTOS_SITE_PKG_DIR = "pkg";
    };
  };

  services.caddy.virtualHosts."hearth.h.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :8473
    '';
  };
}
