{
  config,
  pkgs,
  lib,
  ...
}:
# SMS/RCS <-> Matrix bridge via Google Messages (messages.google.com web pairing).
#
# nixpkgs ships the `mautrix-gmessages` package but (unlike whatsapp/discord/meta)
# NO NixOS module, so this service is hand-rolled. It mirrors the proven pattern
# from ./mautrix-discord.nix: regenerate config from the package example + our
# overrides on every start, generate the appservice registration exactly once so
# the as_token/hs_token stay stable, and splice those stable tokens back into the
# freshly generated config.
#
# This is a bridgev2 bridge: `permissions` lives under `bridge`, `encryption` is
# top-level. Pairing (the Google Messages QR/session) lives in the database, not
# the config, so regenerating the config on each start is safe.
#
# As with the other bridges, tuwunel/conduwuit has no static appservice config
# path: register the generated registration.yaml once via the admin room's
# `register-appservice` command (see the deploy notes in the PR/commit).
let
  user = "mautrix-gmessages";
  dataDir = "/var/lib/mautrix-gmessages";
  configFile = "${dataDir}/config.yaml";
  registrationFile = "${dataDir}/registration.yaml";

  # Appservice port. In use on beefcake: 29318 (whatsapp), 29319/29320 (meta),
  # 29334 (discord). The gmessages example defaults to 29336; keep it.
  port = 29336;

  pkg = pkgs.mautrix-gmessages;
  yq = lib.getExe pkgs.yq-go;

  # Only the fields we care about; everything else comes from the package's
  # example config and the bridge's own defaults.
  settings = {
    homeserver = {
      address = "http://localhost:6167";
      domain = "lyte.dev";
      software = "standard";
    };
    appservice = {
      address = "http://localhost:${toString port}";
      hostname = "127.0.0.1";
      inherit port;
      id = "gmessages";
    };
    database = {
      type = "sqlite3-fk-wal";
      uri = "file:${dataDir}/mautrix-gmessages.db?_txlock=immediate";
    };
    bridge.permissions = {
      "@daniel:lyte.dev" = "admin";
    };
    # Match the working mautrix-discord bridge: allow E2EE but do NOT force it.
    # With default=true the bridge force-encrypts the management room, but olm
    # sessions to the user's devices fail on this tuwunel setup ("Didn't find
    # olm session to encrypt group session"), so the bot's replies (incl. the
    # login QR) never arrive. default=false keeps the management room plaintext.
    encryption = {
      allow = true;
      default = false;
      require = false;
      allow_key_sharing = true;
      pickle_key = "mautrix.bridge.e2ee";
    };
    # Log to journald only (the default also writes a rotating file under ./logs).
    logging = {
      min_level = "info";
      writers = [
        {
          type = "stdout";
          format = "json";
        }
      ];
    };
  };

  overridesYaml = (pkgs.formats.yaml { }).generate "mautrix-gmessages-overrides.yaml" settings;

  # Regenerate config from package example + our overrides, generate the
  # registration once, and keep the appservice tokens stable across restarts.
  initScript = pkgs.writeShellScript "mautrix-gmessages-init" ''
    set -euo pipefail
    umask 0077

    # Fresh example config from the package, then deep-merge our overrides.
    # `mautrix-gmessages -e` REFUSES to overwrite an existing config, so remove
    # any prior one first — this keeps the init idempotent across redeploys and
    # restarts (the registration and its stable tokens are preserved separately
    # below, so regenerating the config loses nothing).
    rm -f '${configFile}'
    ${lib.getExe pkg} -e -c '${configFile}' -n
    # Drop the example's default permissions before the merge so it doesn't keep
    # them (the example grants "*": relay and an @admin:example.com entry);
    # we want only the permissions from our overrides.
    ${yq} -i 'del(.bridge.permissions)' '${configFile}'
    ${yq} -i '. *= load("${overridesYaml}")' '${configFile}'

    # Generate the appservice registration exactly once so tokens stay stable.
    # (--generate-registration is incompatible with --no-update, so this run
    # also rewrites the config; that's fine, the splice below is idempotent.)
    if [ ! -f '${registrationFile}' ]; then
      ${lib.getExe pkg} -g -c '${configFile}' -r '${registrationFile}'
    fi

    # Splice the stable tokens from the registration into the config.
    AS_TOKEN="$(${yq} -r '.as_token' '${registrationFile}')" \
    HS_TOKEN="$(${yq} -r '.hs_token' '${registrationFile}')" \
      ${yq} -i '.appservice.as_token = strenv(AS_TOKEN) | .appservice.hs_token = strenv(HS_TOKEN)' '${configFile}'
  '';
in
{
  services.restic.commonPaths = [ dataDir ];

  users.users.${user} = {
    isSystemUser = true;
    group = user;
    home = dataDir;
  };
  users.groups.${user} = { };

  systemd.services.mautrix-gmessages-init = {
    description = "Prepare mautrix-gmessages config and registration";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = user;
      StateDirectory = "mautrix-gmessages";
      StateDirectoryMode = "0700";
      ExecStart = initScript;
    };
  };

  systemd.services.mautrix-gmessages = {
    description = "mautrix-gmessages SMS/RCS <-> Matrix bridge";
    after = [
      "network-online.target"
      "tuwunel.service"
      "mautrix-gmessages-init.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "mautrix-gmessages-init.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = user;
      Group = user;
      StateDirectory = "mautrix-gmessages";
      StateDirectoryMode = "0700";
      WorkingDirectory = dataDir;
      ExecStart = "${lib.getExe pkg} -c ${configFile} -n";
      Restart = "on-failure";
      RestartSec = "10s";

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ dataDir ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
    };
  };
}
