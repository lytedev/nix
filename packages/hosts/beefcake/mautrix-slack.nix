{
  config,
  pkgs,
  lib,
  ...
}:
let
  dataDir = "/var/lib/mautrix-slack";
  registrationFile = "${dataDir}/slack-registration.yaml";
  settingsFile = "${dataDir}/config.yaml";
  settingsFormat = pkgs.formats.yaml { };
  appservicePort = 29335;

  settings = {
    homeserver = {
      address = "http://localhost:6167";
      domain = "lyte.dev";
    };
    appservice = {
      address = "http://localhost:${toString appservicePort}";
      hostname = "127.0.0.1";
      port = appservicePort;
      id = "slack";
      bot = {
        username = "slackbot";
        displayname = "Slack Bridge Bot";
        avatar = "mxc://maunium.net/pVtzLmChZejGTtVjQOPq";
      };
      as_token = "";
      hs_token = "";
      ephemeral_events = true;
      async_transactions = false;
    };
    database = {
      type = "sqlite3-fk-wal";
      uri = "file:mautrix-slack.db?_txlock=immediate";
    };
    bridge = {
      command_prefix = "!slack";
      permissions = {
        "@daniel:lyte.dev" = "admin";
      };
      relay = {
        enabled = false;
      };
    };
    network = {
      displayname_template = "{{.RealName}}{{if .IsBot}} (bot){{end}}";
      channel_name_template = "{{if and .IsChannel (not .IsPrivate)}}#{{end}}{{.Name}}{{if .IsNoteToSelf}} (you){{end}}";
      team_name_template = "{{.Name}}";
      custom_emoji_reactions = true;
      workspace_avatar_in_rooms = false;
      mute_channels_by_default = false;
      participant_sync_count = 5;
      participant_sync_only_on_create = true;
      conversation_count = -1;
    };
    encryption = {
      allow = true;
      default = true;
      require = false;
      appservice = false;
      allow_key_sharing = false;
      pickle_key = "mautrix.bridge.e2ee";
      verification_levels = {
        receive = "unverified";
        send = "unverified";
        share = "cross-signed-tofu";
      };
    };
    double_puppet = {
      servers = { };
      allow_discovery = false;
    };
    logging = {
      min_level = "info";
      writers = [
        {
          type = "stdout";
          format = "pretty-colored";
          time_format = " ";
        }
      ];
    };
  };

  settingsFileUnsubstituted = settingsFormat.generate "mautrix-slack-config.yaml" settings;
in
{
  services.restic.commonPaths = [ dataDir ];

  users.users.mautrix-slack = {
    isSystemUser = true;
    group = "mautrix-slack";
    home = dataDir;
    description = "Mautrix-Slack bridge user";
  };

  users.groups.mautrix-slack = { };

  systemd.services.mautrix-slack = {
    description = "Mautrix-Slack, a Matrix-Slack puppeting bridge";

    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "tuwunel.service"
    ];
    after = [
      "network-online.target"
      "tuwunel.service"
    ];

    preStart = ''
      # substitute the settings file by environment variables
      test -f '${settingsFile}' && rm -f '${settingsFile}'
      old_umask=$(umask)
      umask 0177
      ${pkgs.envsubst}/bin/envsubst \
        -o '${settingsFile}' \
        -i '${settingsFileUnsubstituted}'
      umask $old_umask

      # generate the appservice's registration file if absent
      if [ ! -f '${registrationFile}' ]; then
        ${pkgs.mautrix-slack}/bin/mautrix-slack \
          --generate-registration \
          --config='${settingsFile}' \
          --registration='${registrationFile}'
      fi
      chmod 640 ${registrationFile}

      umask 0177
      # Overwrite registration tokens in config
      ${pkgs.yq}/bin/yq -sY '.[0].appservice.as_token = .[1].as_token
        | .[0].appservice.hs_token = .[1].hs_token
        | .[0]' \
        '${settingsFile}' '${registrationFile}' > '${settingsFile}.tmp'
      mv '${settingsFile}.tmp' '${settingsFile}'
      umask $old_umask
    '';

    serviceConfig = {
      User = "mautrix-slack";
      Group = "mautrix-slack";
      StateDirectory = "mautrix-slack";
      WorkingDirectory = dataDir;
      ExecStart = ''
        ${pkgs.mautrix-slack}/bin/mautrix-slack \
        --config='${settingsFile}' \
        --registration='${registrationFile}'
      '';
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      Restart = "on-failure";
      RestartSec = "30s";
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallErrorNumber = "EPERM";
      SystemCallFilter = [ "@system-service" ];
      Type = "simple";
      UMask = 27;
    };
    restartTriggers = [ settingsFileUnsubstituted ];
  };
}
