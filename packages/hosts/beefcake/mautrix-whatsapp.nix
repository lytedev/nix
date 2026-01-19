{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.restic.commonPaths = [ "/var/lib/mautrix-whatsapp" ];

  services.mautrix-whatsapp = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://localhost:6167";
        domain = "lyte.dev";
      };
      appservice = {
        address = "http://localhost:29318";
        hostname = "127.0.0.1";
        port = 29318;
      };
      bridge = {
        permissions = {
          "@daniel:lyte.dev" = "admin";
        };
        history_sync = {
          backfill = true;
        };
      };
      encryption = {
        allow = true;
        default = true;
        pickle_key = "mautrix.bridge.e2ee";
      };
    };
  };
}
