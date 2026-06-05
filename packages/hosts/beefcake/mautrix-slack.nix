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
      # No read/typing/presence sync between Matrix and Slack -- the user treats
      # them as separate environments. Disabling here stops the HS from sending
      # m.receipt (and friends) to the bridge entirely, which also eliminates
      # the high-volume backpressure that caused the per-portal queue saturation.
      # (Slack -> Matrix read receipts come through Slack's RTM, not via this
      # flag; there's no clean knob for that direction without disabling double
      # puppeting or patching the fork, and that direction is low-volume so we
      # accept it for now.)
      ephemeral_events = false;
      async_transactions = true;
    };
    database = {
      type = "sqlite3-fk-wal";
      uri = "file:mautrix-slack.db?_txlock=immediate";
    };
    bridge = {
      command_prefix = "!slack";
      personal_filtering_spaces = true;
      # Run per-portal event handlers in a goroutine instead of inline. Without
      # this, one slow Slack API call (e.g. conversations.mark on a high-traffic
      # channel under tier-3 rate limiting) fills the portal's 64-slot queue,
      # which then blocks the workspace's single RTM consumer goroutine, which
      # stalls *every* portal in that workspace. Upstream warns that events may
      # arrive out of order with this on — fine for idempotent read receipts.
      async_events = true;
      permissions = {
        "@daniel:lyte.dev" = "admin";
        "@hookshot:lyte.dev" = "relay";
        "*" = "relay";
      };
      relay = {
        enabled = true;
      };
    };
    network = {
      displayname_template = "{{.RealName}}{{if .IsBot}} (bot){{end}}";
      channel_name_template = "{{if and .IsChannel (not .IsPrivate)}}#{{end}}{{.Name}}{{if .IsNoteToSelf}} (you){{end}}";
      team_name_template = "{{.Name}}";
      custom_emoji_reactions = true;
      workspace_avatar_in_rooms = false;
      mute_channels_by_default = false;
      organize_channels_by_type = true;
      participant_sync_count = 5;
      participant_sync_only_on_create = true;
      conversation_count = -1;
    };
    encryption = {
      allow = true;
      default = false;
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
      secrets = { };
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

      # Add non-exclusive namespace entry for double puppeting real users
      ${pkgs.yq}/bin/yq -sY '.[0].namespaces.users += [{"regex": "^@.*:lyte\\.dev$", "exclusive": false}] | .[0]' \
        '${registrationFile}' > '${registrationFile}.tmp'
      mv '${registrationFile}.tmp' '${registrationFile}'

      umask 0177
      # Overwrite registration tokens in config and set double puppet secret
      ${pkgs.yq}/bin/yq -sY '.[0].appservice.as_token = .[1].as_token
        | .[0].appservice.hs_token = .[1].hs_token
        | .[0].double_puppet.secrets."lyte.dev" = "as_token:" + .[1].as_token
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
