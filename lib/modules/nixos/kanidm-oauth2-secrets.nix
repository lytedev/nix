# Kanidm OAuth2 Secret Fetcher
#
# Fetches OAuth2 client secrets from Kanidm after the server has processed
# its migrations and makes them available as files for consuming services.
#
# Works on any host with VPN connectivity to idm.h.lyte.dev. On beefcake
# (where Kanidm runs), it depends on kanidm.service directly. On remote
# hosts, it depends on tailscaled.service for VPN connectivity.
#
# One-time bootstrap (per Kanidm instance, not per host):
#   1. Deploy with the oauth-secret-reader service account in migrations
#   2. kanidm service-account api-token generate oauth-secret-reader "OAuth secret fetcher"
#   3. Store the token in sops under the key referenced by tokenFile
#   4. Redeploy — all configured secrets are now auto-fetched
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.lyte.kanidm-oauth2-secrets;
  isKanidmServer = config.services.kanidm.enableServer or false;

  secretsDir = "/run/kanidm-oauth2-secrets";

  kanidm = lib.getExe pkgs.kanidm;

  # Generate a fetch stanza for one secret
  mkFetchStanza =
    name: secretCfg:
    let
      dest = "${secretsDir}/${name}.secret";
      client = secretCfg.client;
    in
    ''
      echo "Fetching OAuth2 secret for ${client}..."
      attempt=0
      while [ "$attempt" -lt 5 ]; do
        if secret="$(${kanidm} system oauth2 show-basic-secret ${lib.escapeShellArg client} 2>/dev/null)" && [ -n "$secret" ]; then
          printf '%s' "$secret" | install -m ${lib.escapeShellArg secretCfg.mode} -o ${lib.escapeShellArg secretCfg.owner} -g ${lib.escapeShellArg secretCfg.group} /dev/stdin ${dest}
          echo "  → ${dest}"
          break
        fi
        attempt=$((attempt + 1))
        echo "  attempt $attempt/5 failed, retrying in 2s..."
        sleep 2
      done
      if [ "$attempt" -ge 5 ]; then
        echo "ERROR: Failed to fetch secret for ${client}" >&2
        exit 1
      fi
    '';

  fetchStanzas = lib.concatStringsSep "\n" (lib.mapAttrsToList mkFetchStanza cfg.secrets);
in
{
  options.lyte.kanidm-oauth2-secrets = {
    enable = lib.mkEnableOption "Kanidm OAuth2 secret fetcher";

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing a Kanidm API token for the
        oauth-secret-reader service account. Typically a sops secret path.
      '';
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            client = lib.mkOption {
              type = lib.types.str;
              description = "Kanidm OAuth2 client name (e.g. 'photos.lyte.dev')";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Owner of the secret file";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Group of the secret file";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
              description = "File permissions for the secret file";
            };
          };
        }
      );
      default = { };
      description = ''
        OAuth2 client secrets to fetch from Kanidm.
        Each entry produces a file at /run/kanidm-oauth2-secrets/<name>.secret
        containing the raw client secret string.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.secrets != { }) {
    # Runtime directory for secret files
    systemd.tmpfiles.settings."10-kanidm-oauth2-secrets" = {
      ${secretsDir} = {
        "d" = {
          mode = "0755";
          user = "root";
          group = "root";
        };
      };
    };

    # Oneshot service that fetches secrets after Kanidm is available
    systemd.services.kanidm-oauth2-secrets = {
      description = "Fetch OAuth2 client secrets from Kanidm";
      wantedBy = [ "multi-user.target" ];

      # On beefcake (Kanidm server): wait for kanidm.service
      # On remote hosts: wait for VPN connectivity
      after = [
        "network-online.target"
      ]
      ++ lib.optionals isKanidmServer [ "kanidm.service" ]
      ++ lib.optionals (!isKanidmServer) [ "tailscaled.service" ];
      wants = [
        "network-online.target"
      ]
      ++ lib.optionals isKanidmServer [ "kanidm.service" ]
      ++ lib.optionals (!isKanidmServer) [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        export KANIDM_TOKEN
        KANIDM_TOKEN="$(cat ${cfg.tokenFile})"

        ${fetchStanzas}
      '';
    };

    # Add ordering for consuming services: any service that uses a secret
    # file from this module should start after us. We wire this up by
    # convention — consumers add After=kanidm-oauth2-secrets.service
    # in their own config.
  };
}
