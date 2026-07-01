# Capture OpenObserve alerts into version control.
#
# OpenObserve stores its alerts / alert-templates / destinations in its own DB
# and configures them in the UI — so any alerting we have there is invisible to
# this repo. This module makes them declarative:
#
#   - `openobserve-alerts-export` (installed to $PATH): dump the live alerts +
#     templates + destinations to JSON under this directory's ./definitions so
#     they can be committed. Read-only — safe to run any time. Run as root (it
#     reads the OO root creds from the openobserve.env sops secret):
#         sudo openobserve-alerts-export /etc/nixos/packages/hosts/beefcake/openobserve-alerts/definitions
#
#   - a reconcile oneshot (opt-in) that re-applies the committed ./definitions
#     to OO so the repo is the source of truth. OFF by default because it
#     mutates live OO state and was not testable when written — export +
#     commit real definitions and sanity-check them first, then set
#     `lyte.openobserveAlerts.enable = true;`.
#
# See lib/doc/alerting.md for why OO alerts are Tier 2 (metrics/log-based) while
# "box/pool in trouble" alerts stay host-direct in matrix-alerts.nix.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.lyte.openobserveAlerts;
  ooEnvFile = config.sops.secrets."openobserve.env".path;

  exportScript = pkgs.writeShellApplication {
    name = "openobserve-alerts-export";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      org="''${OO_ORG:-default}"
      base="''${OO_BASE:-http://127.0.0.1:5080}"
      envfile="''${OO_ENV_FILE:-${ooEnvFile}}"
      out="''${1:-.}"

      if [ -r "$envfile" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$envfile"
        set +a
      fi
      if [ -z "''${ZO_ROOT_USER_EMAIL:-}" ] || [ -z "''${ZO_ROOT_USER_PASSWORD:-}" ]; then
        echo "export: no OpenObserve creds — run as root (to read $envfile) or set ZO_ROOT_USER_*" >&2
        exit 1
      fi

      mkdir -p "$out"
      # kind -> output filename
      for kind in alerts alerts/templates alerts/destinations; do
        fname="$out/$(echo "$kind" | tr / -).json"
        if curl -sf -u "$ZO_ROOT_USER_EMAIL:$ZO_ROOT_USER_PASSWORD" \
            "$base/api/$org/$kind" | jq -S . > "$fname"; then
          echo "wrote $fname"
        else
          echo "export: failed to fetch $kind" >&2
        fi
      done
      echo "Done. Review + commit the JSON under $out."
    '';
  };
in
{
  options.lyte.openobserveAlerts.enable = lib.mkEnableOption ''
    reconciling checked-in OpenObserve alert definitions into the live OO API on
    activation and hourly. Mutates live OO state; only enable after exporting +
    committing real definitions and validating them'';

  config = {
    # The export helper is always available (read-only).
    environment.systemPackages = [ exportScript ];

    # Opt-in reconcile: apply ./definitions to OO. Runs as root to read the OO
    # root creds from the openobserve.env sops secret.
    systemd.services.openobserve-alerts-reconcile = lib.mkIf cfg.enable {
      description = "Reconcile checked-in OpenObserve alert definitions into OpenObserve";
      after = [
        "openobserve.service"
        "sops-nix.service"
      ];
      wants = [ "openobserve.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      environment = {
        DEFS_DIR = "${./definitions}";
        OO_ENV_FILE = ooEnvFile;
        OO_BASE = "http://127.0.0.1:5080";
        OO_ORG = "default";
      };
      script = "${pkgs.python3}/bin/python3 ${./reconcile.py}";
    };

    systemd.timers.openobserve-alerts-reconcile = lib.mkIf cfg.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10m";
        OnUnitActiveSec = "1h";
        Unit = "openobserve-alerts-reconcile.service";
      };
    };
  };
}
