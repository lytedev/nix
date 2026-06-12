# New-Inbox-mail → Matrix notifications.
#
# A small daemon authenticates to stalwart's JMAP with a scoped, non-expiring
# API key (a credential on daniel@lyte.dev, restricted via a Replace allowlist
# to exactly authenticate + Mailbox/get + Email/get,query,changes), listens on
# the JMAP EventSource, and posts one line per new Inbox message to a
# matrix-hookshot generic webhook (no dedicated Matrix bot/appservice —
# hookshot is already registered with tuwunel).
#
# Both secrets are declarative via sops, so there is no interactive bootstrap
# and nothing to re-seed — the API key never expires and does not roll:
#   - jmap-matrix-notify-api-key      (the Stalwart API key string)
#   - jmap-matrix-notify-webhook-url  (the hookshot webhook URL)
#
# Minting/rotating the API key: mint via the JMAP management method
# `x:ApiKey/set` (create with permissions {"@type":"Replace","permissions":
# {authenticate,jmapMailboxGet,jmapEmailGet,jmapEmailQuery,jmapEmailChanges}},
# expiresAt null) using an admin/daniel bearer token; the response `secret`
# (an `API_…` string) goes into sops. get-token.sh obtains the bearer token.
# Webhook setup (one-time, in Matrix): invite hookshot to the room,
# `!hookshot webhook mail-inbox`, put the URL in sops.
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

  sops.secrets.jmap-matrix-notify-api-key = {
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
      JMAP_BASE = "https://mail.lyte.dev";
      WEBHOOK_URL_FILE = config.sops.secrets.jmap-matrix-notify-webhook-url.path;
      API_KEY_FILE = config.sops.secrets.jmap-matrix-notify-api-key.path;
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
