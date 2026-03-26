{
  config,
  pkgs,
  lib,
  ...
}:
let
  registrationFile = "/var/lib/mautrix-discord/discord-registration.yaml";
in
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

  # WORKAROUND: The NixOS mautrix-discord module's registration service
  # unconditionally regenerates tokens on every restart, breaking the
  # homeserver's stored appservice registration. Override ExecStart to
  # only generate when the file doesn't exist, preserving stable tokens.
  systemd.services.mautrix-discord-registration.serviceConfig.ExecStart = lib.mkForce (
    let
      configFile = "/var/lib/mautrix-discord/config.yaml";
      configUnsubstituted = config.services.mautrix-discord.settings;
    in
    toString (
      pkgs.writeShellScript "mautrix-discord-registration-safe" ''
        set -euo pipefail

        # Substitute environment variables into config
        old_umask=$(umask)
        umask 0177
        ${pkgs.envsubst}/bin/envsubst \
          -o '${configFile}' \
          -i '${(pkgs.formats.yaml { }).generate "discord-config-unsubstituted.yaml" configUnsubstituted}'

        if [ -f '${registrationFile}' ]; then
          echo "Registration file exists, preserving existing tokens"
          # Copy existing tokens into config
          ${pkgs.yq}/bin/yq -sY '
            .[0].appservice.as_token = .[1].as_token
            | .[0].appservice.hs_token = .[1].hs_token
            | .[0]
          ' '${configFile}' '${registrationFile}' > '${configFile}.tmp'
          mv '${configFile}.tmp' '${configFile}'
        else
          echo "No registration file, generating new one"
          ${pkgs.mautrix-discord}/bin/mautrix-discord \
            --generate-registration \
            --config='${configFile}' \
            --registration='${registrationFile}'
          # Copy new tokens into config
          ${pkgs.yq}/bin/yq -sY '
            .[0].appservice.as_token = .[1].as_token
            | .[0].appservice.hs_token = .[1].hs_token
            | .[0]
          ' '${configFile}' '${registrationFile}' > '${configFile}.tmp'
          mv '${configFile}.tmp' '${configFile}'
        fi

        umask $old_umask
        chown :mautrix-discord-registration '${registrationFile}'
        chmod 640 '${registrationFile}'
      ''
    )
  );
}
