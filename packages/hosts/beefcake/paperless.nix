{ config, ... }:
{
  systemd.tmpfiles.settings = {
    "10-paperless" = {
      "/storage/paperless" = {
        "d" = {
          mode = "0750";
          user = "paperless";
          group = "paperless";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/paperless"
  ];

  sops.secrets.paperless-superuser-password = {
    owner = "paperless";
    group = "paperless";
    mode = "400";
  };

  services.paperless = {
    enable = true;
    dataDir = "/storage/paperless";
    passwordFile = config.sops.secrets.paperless-superuser-password.path;
    settings.PAPERLESS_URL = "https://paperless.h.lyte.dev";
  };

  services.caddy.virtualHosts."paperless.h.lyte.dev" = {
    extraConfig = "reverse_proxy :${toString config.services.paperless.port}";
  };
}
