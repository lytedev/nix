# Custom stalwart 0.16 NixOS module.
#
# Replaces the upstream nixpkgs services.stalwart (which generates a TOML
# config file — incompatible with 0.16).  The 0.16 model is:
#   - A minimal config.json on disk → tells stalwart where its datastore is
#   - Everything else lives in the database, applied via `stalwart-cli apply`
#     from a declarative plan (JSON array of operations)
#
# The apply flow (validated against a live 0.16.8 sandbox, 2026-06-09):
#   1. wait for /healthz/live
#   2. ensure the primary Domain exists, capture its id
#   3. ensure exactly one Certificate exists (create or refresh-from-files),
#      capture its id, prune duplicates
#   4. substitute @DOMAIN_ID@ / @CERT_ID@ / custom credential placeholders
#      into the plan template at runtime
#   5. stalwart-cli apply the resolved plan
#
# Why runtime id substitution instead of JMAP "#ref" syntax:
#   - "#ref" for Certificate ids hits a server-side parse bug (0.16.8)
#   - create ops for existing objects fail with primaryKeyViolation, which
#     cascades into "#ref" resolution failures for every dependent op on
#     re-apply — silently leaving DKIM unsigned. Literal ids avoid the
#     entire class of problems and make re-apply fully idempotent
#     (verified: two consecutive runs, zero failed operations).
#
# Plan format notes (verified against stalwart-cli 1.0.0):
#   - The plan file is a JSON ARRAY of ops, not NDJSON
#   - JMAP set<...> fields (bind, headers, redirectUris) are encoded as
#     {"value": true} maps, NOT arrays
#   - OAuthClient's key field is `clientId`, not `name`
#   - MtaRoute Relay `authUsername` is a plain string; `authSecret` accepts
#     {"@type":"File","filePath":...}
#
# CAUTION: a plan with `destroy NetworkListener {}` that fails before the
# creates leaves the DB with no HTTP listener — the server then boots
# unreachable except via STALWART_RECOVERY_MODE=1. Listener changes also
# only take effect after a service restart (live rebind does not happen).
#
# Migration from 0.15: see issues/open/stalwart-0.16-upgrade.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.stalwart;

  # Minimal config.json — only the datastore pointer.
  configJson = pkgs.writeText "stalwart-config.json" (builtins.toJSON cfg.storeConfig);

  # Plan template: JSON array. @DOMAIN_ID@, @CERT_ID@ and custom
  # placeholders are substituted at apply time.
  planTemplate = pkgs.writeText "stalwart-plan-template.json" (builtins.toJSON cfg.plan);

  credsDir = "/run/credentials/stalwart.service";
  applyCreds = "/run/credentials/stalwart-apply.service";
in
{
  options.services.stalwart = {
    enable = lib.mkEnableOption "Stalwart mail and collaboration server (0.16+)";

    package = lib.mkPackageOption pkgs "stalwart" { };

    cliPackage = lib.mkPackageOption pkgs "stalwart-cli" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "stalwart";
      description = "User to run stalwart as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "stalwart";
      description = "Group to run stalwart as.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/stalwart";
      description = "Primary data directory (also used as the default store path).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open TCP firewall ports listed in `firewallPorts`.";
    };

    firewallPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Ports to open in the firewall when openFirewall = true.";
    };

    credentials = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Credentials loaded into stalwart.service via systemd LoadCredential.
        Accessible inside the server process at
        /run/credentials/stalwart.service/<name>.
      '';
      example = {
        admin_password = "/run/secrets/stalwart-admin-password";
        dkim_private_key = "/run/secrets/stalwart-dkim-key";
      };
    };

    # config.json — minimal JSON telling stalwart where the database is.
    # Format: { "@type": "RocksDb", "path": "/storage/stalwart/rocksdb" }
    storeConfig = lib.mkOption {
      type = lib.types.attrs;
      defaultText = lib.literalExpression ''
        { "@type" = "RocksDb"; path = "''${config.services.stalwart.dataDir}/db"; }
      '';
      description = ''
        Content of the on-disk config.json file.  Must describe only the
        primary datastore — all other settings belong in `plan`.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = ''
        Primary mail domain.  The apply service ensures a Domain object with
        this name exists and substitutes its id for @DOMAIN_ID@ in the plan.
      '';
    };

    certificateFiles = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            certificate = lib.mkOption {
              type = lib.types.str;
              description = "Path to the PEM certificate chain (read by the server at apply time).";
            };
            privateKey = lib.mkOption {
              type = lib.types.str;
              description = "Path to the PEM private key (read by the server at apply time).";
            };
          };
        }
      );
      default = null;
      description = ''
        If set, the apply service ensures exactly one Certificate object
        exists (creating it from these files, or refreshing the existing
        one), prunes duplicates, and substitutes its id for @CERT_ID@ in
        the plan.  Paths must be readable by the stalwart server process —
        File refs are resolved server-side.
      '';
    };

    planSubstitutions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra placeholder → credential-name substitutions applied to the
        plan at apply time.  The credential value (first line) replaces the
        placeholder.  Use for values that must not land in the nix store
        (e.g. relay usernames) but are not File-ref-capable fields.
      '';
      example = {
        "@SMTP_RELAY_USERNAME@" = "smtp_relay_username";
      };
    };

    plan = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = ''
        List of operation objects applied via `stalwart-cli apply` after
        startup (serialized as a JSON array).  Operations are processed
        destroy-first (in reverse) then create/update (in order).

        @DOMAIN_ID@ and @CERT_ID@ placeholders are substituted with the
        runtime ids of the `domain` / `certificateFiles` objects.

        JMAP set<> fields (bind, headers, redirectUris, …) must be encoded
        as { "<value>" = true; } attrsets, not lists.
      '';
    };

    adminAccounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Account names (as stored, e.g. "daniel") to grant the
        System Administrator role after each plan apply.  Accounts are
        looked up by name at apply time; missing accounts are skipped with
        a warning (accounts themselves are user data, not plan-managed).
      '';
    };

    applyUrl = lib.mkOption {
      type = lib.types.str;
      description = "URL stalwart-cli uses to reach the running server (e.g. http://[::1]:8080).";
    };

    applyAdminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Admin username for stalwart-cli apply authentication.";
    };

    applyAdminPasswordCredential = lib.mkOption {
      type = lib.types.str;
      description = ''
        Name of the credential (key in `credentials`) holding the admin password
        used by stalwart-cli apply.
      '';
    };

    # STALWART_RECOVERY_ADMIN env var — always-available fallback admin.
    # Mirrors 0.15's authentication.fallback-admin.
    recoveryAdminCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If set, the named credential (from `credentials`) is used to populate
        the STALWART_RECOVERY_ADMIN environment variable as "<user>:<password>".
        This lets stalwart-cli apply authenticate even when no admin account
        exists in the database.  Equivalent to 0.15's
        authentication.fallback-admin setting.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.stalwart.storeConfig = lib.mkDefault {
      "@type" = "RocksDb";
      path = "${cfg.dataDir}/db";
    };

    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' - '${cfg.user}' '${cfg.group}' - -"
    ];

    systemd.services.stalwart = {
      description = "Stalwart Mail and Collaboration Server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "network.target"
      ];

      serviceConfig = {
        Type = "simple";
        LimitNOFILE = 65536;
        KillMode = "process";
        KillSignal = "SIGINT";
        Restart = "on-failure";
        RestartSec = 5;
        SyslogIdentifier = "stalwart";

        # LoadCredential files are readable by the service user, so the
        # wrapper runs as cfg.user (no "+" prefix — that would run the
        # whole server as root).
        ExecStart =
          if cfg.recoveryAdminCredential != null then
            "${pkgs.writeShellScript "stalwart-start" ''
              cred="$CREDENTIALS_DIRECTORY/${cfg.recoveryAdminCredential}"
              STALWART_RECOVERY_ADMIN="${cfg.applyAdminUser}:$(cat "$cred")"
              export STALWART_RECOVERY_ADMIN
              exec ${lib.getExe cfg.package} --config=${configJson}
            ''}"
          else
            "${lib.getExe cfg.package} --config=${configJson}";

        LoadCredential = lib.mapAttrsToList (key: value: "${key}:${value}") cfg.credentials;

        ReadWritePaths = [ cfg.dataDir ];
        StateDirectory = "stalwart";
        CacheDirectory = "stalwart";

        User = cfg.user;
        Group = cfg.group;

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

        # Hardening
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateUsers = false; # incompatible with CAP_NET_BIND_SERVICE
        ProcSubset = "pid";
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

    systemd.services.stalwart-apply = lib.mkIf (cfg.plan != [ ]) {
      description = "Apply Stalwart configuration plan";
      wantedBy = [ "multi-user.target" ];
      after = [ "stalwart.service" ];
      requires = [ "stalwart.service" ];

      # Re-apply whenever the plan template changes (new nixos generation).
      restartTriggers = [ planTemplate ];

      path = with pkgs; [
        curl
        jq
        gnused
        coreutils
      ];

      environment = {
        STALWART_URL = cfg.applyUrl;
        STALWART_USER = cfg.applyAdminUser;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Needs to read the admin credential; runs as root like other
        # provisioning oneshots. PrivateTmp for the resolved plan file
        # (it contains substituted secrets).
        User = "root";
        PrivateTmp = true;

        LoadCredential = [
          "${cfg.applyAdminPasswordCredential}:${cfg.credentials.${cfg.applyAdminPasswordCredential}}"
        ]
        ++ lib.mapAttrsToList (_placeholder: credName: "${credName}:${cfg.credentials.${credName}}") (
          lib.filterAttrs (_p: credName: credName != cfg.applyAdminPasswordCredential) cfg.planSubstitutions
        );
      };

      script = ''
        set -euo pipefail
        cli=${lib.getExe cfg.cliPackage}
        export STALWART_PASSWORD="$(cat "${applyCreds}/${cfg.applyAdminPasswordCredential}")"
        rundir=$(mktemp -d)
        trap 'rm -rf "$rundir"' EXIT

        echo "[1/5] waiting for stalwart at ${cfg.applyUrl}..."
        until curl -sf --max-time 5 "${cfg.applyUrl}/healthz/live" >/dev/null 2>&1; do
          sleep 2
        done

        echo "[2/5] ensuring domain ${cfg.domain}..."
        domain_id=$($cli query Domain --json --no-color | jq -r '.[] | select(.name=="${cfg.domain}").id' | head -1)
        if [ -z "$domain_id" ]; then
          echo '[{"@type":"create","object":"Domain","value":{"dom":{"name":"${cfg.domain}"}}}]' > "$rundir/domain.json"
          $cli apply --file "$rundir/domain.json" --no-color
          domain_id=$($cli query Domain --json --no-color | jq -r '.[] | select(.name=="${cfg.domain}").id' | head -1)
        fi
        echo "  domain id: $domain_id"

        ${lib.optionalString (cfg.certificateFiles != null) ''
            echo "[3/5] ensuring certificate..."
            cert_id=$($cli get SystemSettings singleton --json --no-color | jq -r '.defaultCertificateId // empty')
            all_certs=$($cli query Certificate --json --no-color | jq -r '.[].id')
            if [ -z "$cert_id" ] || ! grep -qx "$cert_id" <<<"$all_certs"; then
              cert_id=$(head -1 <<<"$all_certs" || true)
            fi
            if [ -z "$cert_id" ]; then
              cat > "$rundir/cert.json" <<'CERTEOF'
          [{"@type":"create","object":"Certificate","value":{"cert":{"certificate":{"@type":"File","filePath":"${cfg.certificateFiles.certificate}"},"privateKey":{"@type":"File","filePath":"${cfg.certificateFiles.privateKey}"}}}}]
          CERTEOF
              $cli apply --file "$rundir/cert.json" --no-color
              cert_id=$($cli query Certificate --json --no-color | jq -r '.[0].id')
            else
              cat > "$rundir/cert-update.json" <<CERTEOF
          [{"@type":"update","object":"Certificate","id":"$cert_id","value":{"certificate":{"@type":"File","filePath":"${cfg.certificateFiles.certificate}"},"privateKey":{"@type":"File","filePath":"${cfg.certificateFiles.privateKey}"}}}]
          CERTEOF
              $cli apply --file "$rundir/cert-update.json" --no-color
            fi
            echo "  cert id: $cert_id"
            extra=$(grep -vx "$cert_id" <<<"$all_certs" | paste -sd, - || true)
            if [ -n "$extra" ]; then
              echo "  pruning duplicate certificates: $extra"
              $cli delete Certificate --ids "$extra" --no-color
            fi
        ''}

        echo "[4/5] resolving plan template..."
        sed -e "s/@DOMAIN_ID@/$domain_id/g" \
          ${lib.optionalString (cfg.certificateFiles != null) ''-e "s/@CERT_ID@/$cert_id/g" \''}
          ${
            lib.concatStringsSep " \\\n  " (
              lib.mapAttrsToList (
                placeholder: credName: ''-e "s|${placeholder}|$(head -n1 "${applyCreds}/${credName}")|g"''
              ) cfg.planSubstitutions
            )
          } \
          ${planTemplate} > "$rundir/plan.json"

        echo "[5/5] applying plan..."
        $cli apply --file "$rundir/plan.json" --no-color

        ${lib.optionalString (cfg.adminAccounts != [ ]) ''
          echo "[post] granting System Administrator role to: ${lib.concatStringsSep ", " cfg.adminAccounts}"
          role_id=$($cli query Role --json --no-color | jq -r '.[].id' | while read -r rid; do
            desc=$($cli get Role "$rid" --json --no-color | jq -r '.description // empty')
            if [ "$desc" = "System Administrator" ]; then echo "$rid"; break; fi
          done)
          if [ -z "$role_id" ]; then
            echo "  WARNING: System Administrator role not found; skipping grants"
          else
            for want in ${lib.concatStringsSep " " cfg.adminAccounts}; do
              acct_id=$($cli query Account --json --no-color | jq -r '.[].id' | while read -r aid; do
                name=$($cli get Account "$aid" --json --no-color | jq -r '.name // empty')
                if [ "$name" = "$want" ]; then echo "$aid"; break; fi
              done)
              if [ -z "$acct_id" ]; then
                echo "  WARNING: account '$want' not found; skipping"
                continue
              fi
              printf '[{"@type":"update","object":"Account","id":"%s","value":{"roleIds":{"%s":true}}}]' "$acct_id" "$role_id" > "$rundir/role.json"
              $cli apply --file "$rundir/role.json" --no-color
              echo "  granted to $want ($acct_id)"
            done
          fi
        ''}
        echo "stalwart-apply complete"
      '';
    };

    environment.systemPackages = [
      cfg.package
      cfg.cliPackage
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall cfg.firewallPorts;
  };
}
