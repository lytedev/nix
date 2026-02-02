{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.restic.commonPaths = [ "/var/lib/mautrix-discord" ];

  services.mautrix-discord = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://localhost:6167";
        domain = "lyte.dev";
      };
      appservice = {
        address = "http://localhost:29334";
        hostname = "127.0.0.1";
        port = 29334;
        database = {
          type = "sqlite3-fk-wal";
          uri = "file:mautrix-discord.db?_txlock=immediate";
        };
      };
      bridge = {
        permissions = {
          "@daniel:lyte.dev" = "admin";
          "*" = "relay";
        };
        encryption = {
          allow = true;
          default = false;
          allow_key_sharing = true;
          pickle_key = "mautrix.bridge.e2ee";
        };
      };
    };
  };
}
