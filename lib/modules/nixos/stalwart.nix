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

    oidcDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        If set, the apply service ensures a Directory object with this
        content exists (matched by `description` — create if missing,
        update-by-id otherwise so the id stays stable across applies) and
        substitutes its id for @OIDC_DIRECTORY_ID@ in the plan.  Use with
        an `Authentication.directoryId` update op to enable it.  Must
        include `"@type"` (e.g. "Oidc") and a unique `description`.
      '';
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

    accountAliases = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        daniel = [
          "dax@lyte.dev"
          "oliver@lyte.dev"
        ];
      };
      description = ''
        Extra email addresses (aliases) to ensure on existing accounts after
        each plan apply, keyed by account name (as stored, e.g. "daniel").
        Mail to an alias is delivered to that account's mailbox.  Each address
        must be in the configured `domain`.  Use "@${"\${domain}"}" (empty local
        part) for a domain CATCH-ALL (delivers any otherwise-unmatched address
        to that account).  The account's `aliases` (a list<EmailAlias>) is
        replaced from this list on each apply (declarative source of truth);
        the primary `emailAddress` is never touched; missing accounts are
        skipped with a warning.  Like adminAccounts, this exists because
        accounts are user data, not plan-managed — codifying the aliases here
        means they survive a DB rebuild instead of silently vanishing.
      '';
    };

    catchAllAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "daniel@lyte.dev";
      description = ''
        If set, configures the domain catch-all: any address in `domain` that
        does not match a real mailbox or alias is delivered to this address.
        Set on the Domain object (`catchAllAddress`) at apply time. NOTE: a
        catch-all accepts mail to every possible address (a spam magnet) and
        removes the "mailbox does not exist" rejection of bogus addresses.
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

      script =
        let
          totalSteps =
            4
            + (if cfg.certificateFiles != null then 1 else 0)
            + (if cfg.oidcDirectory != null then 1 else 0)
            + (if cfg.adminAccounts != [ ] then 1 else 0)
            + (if cfg.accountAliases != { } then 1 else 0);
        in
        ''
            set -euo pipefail
            cli=${lib.getExe cfg.cliPackage}
            export STALWART_PASSWORD="$(cat "${applyCreds}/${cfg.applyAdminPasswordCredential}")"
            rundir=$(mktemp -d)
            trap 'rm -rf "$rundir"' EXIT

            _step=0
            step() {
              _step=$((_step + 1))
              echo "[$_step/${toString totalSteps}] $1"
            }

            step "waiting for stalwart at ${cfg.applyUrl}..."
          until curl -sf --max-time 5 "${cfg.applyUrl}/healthz/live" >/dev/null 2>&1; do
            sleep 2
          done

          step "ensuring domain ${cfg.domain}..."
          domain_id=$($cli query Domain --json --no-color | jq -r '.[] | select(.name=="${cfg.domain}").id' | head -1)
          if [ -z "$domain_id" ]; then
            echo '[{"@type":"create","object":"Domain","value":{"dom":{"name":"${cfg.domain}"}}}]' > "$rundir/domain.json"
            $cli apply --file "$rundir/domain.json" --no-color
            domain_id=$($cli query Domain --json --no-color | jq -r '.[] | select(.name=="${cfg.domain}").id' | head -1)
          fi
          echo "  domain id: $domain_id"
          ${lib.optionalString (cfg.catchAllAddress != null) ''
            # Domain catch-all: unmatched addresses -> this address. Simple
            # Option<String> field on the Domain object.
            printf '[{"@type":"update","object":"Domain","id":"%s","value":{"catchAllAddress":"${cfg.catchAllAddress}"}}]' "$domain_id" > "$rundir/catchall.json"
            $cli apply --file "$rundir/catchall.json" --no-color
            echo "  catch-all -> ${cfg.catchAllAddress}"
          ''}

          ${lib.optionalString (cfg.certificateFiles != null) ''
              step "ensuring certificate..."
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

          ${lib.optionalString (cfg.oidcDirectory != null) ''
              step "ensuring OIDC directory..."
              # The query LIST view omits most fields (description comes back
              # null — same trap as Account.name); match via per-id `get`.
              dir_desc=${lib.escapeShellArg cfg.oidcDirectory.description}
              find_dir_id() {
                $cli query Directory --json --no-color | jq -r '.[].id' | while read -r did; do
                  desc=$($cli get Directory "$did" --json --no-color | jq -r '.description // empty')
                  if [ "$desc" = "$dir_desc" ]; then echo "$did"; fi
                done
              }
              all_matching=$(find_dir_id)
              dir_id=$(head -1 <<<"$all_matching" || true)
              if [ -z "$dir_id" ]; then
                cat > "$rundir/dir.json" <<'DIREOF'
            [{"@type":"create","object":"Directory","value":{"dir":${builtins.toJSON cfg.oidcDirectory}}}]
            DIREOF
                $cli apply --file "$rundir/dir.json" --no-color
                dir_id=$(find_dir_id | head -1)
              else
                cat > "$rundir/dir-update.json" <<DIREOF
            [{"@type":"update","object":"Directory","id":"$dir_id","value":${builtins.toJSON cfg.oidcDirectory}}]
            DIREOF
                $cli apply --file "$rundir/dir-update.json" --no-color
                extra_dirs=$(grep -vx "$dir_id" <<<"$all_matching" | paste -sd, - || true)
                if [ -n "$extra_dirs" ]; then
                  echo "  pruning duplicate directories: $extra_dirs"
                  $cli delete Directory --ids "$extra_dirs" --no-color
                fi
              fi
              if [ -z "$dir_id" ]; then
                echo "ERROR: OIDC directory id could not be determined; refusing to substitute an empty id" >&2
                exit 1
              fi
              echo "  oidc directory id: $dir_id"
          ''}

          step "resolving plan template..."
          sed -e "s/@DOMAIN_ID@/$domain_id/g" \
            ${lib.optionalString (cfg.certificateFiles != null) ''-e "s/@CERT_ID@/$cert_id/g" \''}
            ${lib.optionalString (cfg.oidcDirectory != null) ''-e "s/@OIDC_DIRECTORY_ID@/$dir_id/g" \''}
            ${
              lib.concatStringsSep " \\\n  " (
                lib.mapAttrsToList (
                  placeholder: credName: ''-e "s|${placeholder}|$(head -n1 "${applyCreds}/${credName}")|g"''
                ) cfg.planSubstitutions
              )
            } \
            ${planTemplate} > "$rundir/plan.json"

          step "applying plan..."
          $cli apply --file "$rundir/plan.json" --no-color

          ${lib.optionalString (cfg.adminAccounts != [ ]) ''
            # Account.roles is a tagged variant; {"@type":"Admin"} grants full
            # admin. (The CLI schema's roleIds field is rejected by the server
            # on update — sandbox-verified 2026-06-10.)
            step "granting Admin role to: ${lib.concatStringsSep ", " cfg.adminAccounts}"
            for want in ${lib.concatStringsSep " " cfg.adminAccounts}; do
              acct_id=$($cli query Account --json --no-color | jq -r '.[].id' | while read -r aid; do
                name=$($cli get Account "$aid" --json --no-color | jq -r '.name // empty')
                if [ "$name" = "$want" ]; then echo "$aid"; break; fi
              done)
              if [ -z "$acct_id" ]; then
                echo "  WARNING: account '$want' not found; skipping"
                continue
              fi
              printf '[{"@type":"update","object":"Account","id":"%s","value":{"roles":{"@type":"Admin"}}}]' "$acct_id" > "$rundir/role.json"
              $cli apply --file "$rundir/role.json" --no-color
              echo "  granted to $want ($acct_id)"
            done
          ''}

          ${lib.optionalString (cfg.accountAliases != { }) (
            ''
              step "ensuring account email aliases"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (acct: aliases: ''
                want=${lib.escapeShellArg acct}
                acct_id=$($cli query Account --json --no-color | jq -r '.[].id' | while read -r aid; do
                  name=$($cli get Account "$aid" --json --no-color | jq -r '.name // empty')
                  if [ "$name" = "$want" ]; then echo "$aid"; break; fi
                done)
                if [ -z "$acct_id" ]; then
                  echo "  WARNING: account '$want' not found; skipping aliases"
                else
                  # Account aliases are a `list<EmailAlias>` where each entry is
                  # {enabled, name, domainId, description}: `name` is the LOCAL
                  # part and `name`+`domainId` form the address (an empty name is
                  # the domain catch-all). The primary (`emailAddress`) is
                  # server-set and untouched. We replace the whole list from the
                  # config (declarative source of truth) — idempotent. Aliases
                  # must be in ${cfg.domain} (the resolved domain_id).
                  # A List<EmailAlias> is patched as an index-keyed map
                  # ({"0":{...},"1":{...}}), not a JSON array (that's what the
                  # "invalid key"->"invalid value" error progression revealed).
                  aliases_obj=$(jq -cn \
                    --arg domain '${cfg.domain}' --arg did "$domain_id" \
                    --argjson add '${builtins.toJSON aliases}' '
                    [ $add[] | { enabled: true, name: (sub("@" + $domain + "$"; "")), domainId: $did } ]
                    | to_entries | map({ (.key | tostring): .value }) | add // {}')
                  printf '[{"@type":"update","object":"Account","id":"%s","value":{"aliases":%s}}]' "$acct_id" "$aliases_obj" > "$rundir/alias.json"
                  $cli apply --file "$rundir/alias.json" --no-color
                  echo "  ensured aliases on $want ($acct_id): ${lib.concatStringsSep ", " aliases}"
                fi
              '') cfg.accountAliases
            )
          )}
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
