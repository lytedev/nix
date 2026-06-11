# New-Inbox-mail → Matrix notifications.
#
# A small daemon holds daniel's Kanidm session (rolling refresh token for
# the bulwark-webmail public client), listens on stalwart's JMAP
# EventSource, and posts one line per new Inbox message to a
# matrix-hookshot generic webhook (no dedicated Matrix bot/appservice —
# hookshot is already registered with tuwunel).
#
# One-time bootstrap after deploy:
#   1. On a workstation: get-token.sh --save-refresh > refresh_token
#      (interactive Kanidm login; see /tmp/mailctl/get-token.sh history)
#   2. install -m 0600 -o jmap-matrix-notify refresh_token \
#        /var/lib/jmap-matrix-notify/refresh_token
#   3. In Matrix: invite hookshot to the target room,
#      `!hookshot webhook mail-inbox`, put the URL in sops
#      (jmap-matrix-notify-webhook-url).
# The refresh token rolls forward on every renewal; if the service is down
# past kanidm's refresh window the bootstrap must be repeated.
{
  config,
  pkgs,
  ...
}:
{
  sops.secrets.jmap-matrix-notify-webhook-url = {
    mode = "0400";
    owner = "jmap-matrix-notify";
  };

  users.groups.jmap-matrix-notify = { };
  users.users.jmap-matrix-notify = {
    isSystemUser = true;
    group = "jmap-matrix-notify";
  };

  systemd.services.jmap-matrix-notify = {
    description = "Notify Matrix (hookshot webhook) about new Inbox mail";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "stalwart.service"
    ];
    wants = [ "network-online.target" ];

    environment = {
      KANIDM_ISSUER = "https://idm.h.lyte.dev/oauth2/openid/bulwark-webmail";
      OAUTH_CLIENT_ID = "bulwark-webmail";
      JMAP_BASE = "https://mail.lyte.dev";
      WEBHOOK_URL_FILE = config.sops.secrets.jmap-matrix-notify-webhook-url.path;
    };

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./notify.py}";
      User = "jmap-matrix-notify";
      Group = "jmap-matrix-notify";
      StateDirectory = "jmap-matrix-notify";
      Restart = "always";
      RestartSec = 10;

      # Hardening
      CapabilityBoundingSet = [ "" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      UMask = "0077";
    };
  };
}
