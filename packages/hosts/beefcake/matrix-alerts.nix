# Host-direct systemd alerts → Matrix (OO-independent).
#
# The live metrics/logs pipeline ships to OpenObserve (OTel collector, see
# lib/modules/nixos/server.nix), and OpenObserve stores its data on this very
# host/pool. So — exactly as disk-alerts.nix already argues for smartd/ZED —
# the failure classes that mean "this box or its storage is in trouble" are
# alerted host-direct, without depending on the metrics stack:
#
#   - any of the critical service units failing (OnFailure → Matrix), and
#   - a local filesystem crossing 90% full.
#
# Both post to the SAME matrix-hookshot generic webhook the disk alerts use
# (`disk-alert-webhook-url` in sops), so there is no new secret and this works
# on deploy. See lib/doc/alerting.md for the full picture.
#
# NOTE (repo policy): the tiny hookshot-poster below is a deliberate duplicate
# of disk-alerts.nix's `disk-alert-notify` rather than a shared refactor —
# features don't refactor shared code inline. Extracting a `lyte.matrix-notify`
# helper is a fast-follow.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  webhookSecret = config.sops.secrets.disk-alert-webhook-url.path;

  # Reads the alert text on stdin and posts it to the hookshot webhook.
  # Best-effort: never fails its caller (a failed OnFailure handler that itself
  # fails is just noise), no-ops if the webhook secret is absent/empty.
  matrixAlertPost = pkgs.writeShellApplication {
    name = "matrix-alert-post";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      webhook="$(cat ${webhookSecret} 2>/dev/null || true)"
      if [ -z "$webhook" ]; then
        echo "matrix-alert-post: no webhook url available" >&2
        exit 0
      fi
      body="$(cat || true)"
      text="''${body:0:3500}"
      payload="$(jq -n --arg t "$text" '{text: $t}')"
      curl --fail --silent --show-error --max-time 20 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        "$webhook" >/dev/null || echo "matrix-alert-post: post failed" >&2
    '';
  };

  # Units whose failure should page Matrix. These are long-running services
  # (notify/simple), so a `failed` state is a real problem — a normal restart
  # during a deploy is not a failure and does NOT trigger OnFailure.
  criticalUnits = [
    "caddy"
    "stalwart"
    "forgejo"
    "tuwunel"
    "knot"
    "headscale"
  ];
in
{
  systemd.services =
    # Wire OnFailure on each critical unit. `%n` expands to the failing unit's
    # full name, so the template instance is e.g. alert-unit-failed@caddy.service.
    lib.genAttrs criticalUnits (_: {
      unitConfig.OnFailure = [ "alert-unit-failed@%n.service" ];
    })
    // {
      # Templated notifier: `%i` is the failing unit (e.g. "caddy.service").
      "alert-unit-failed@" = {
        description = "Alert Matrix that %i failed";
        # Don't let a notifier that fails trigger anyone's OnFailure in turn.
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.systemd
          pkgs.coreutils
        ];
        scriptArgs = "%i";
        script = ''
          unit="''${1:-unknown}"
          host="$(uname -n)"
          status="$(systemctl --no-pager --lines=0 status "$unit" 2>&1 | head -n 6 || true)"
          logs="$(journalctl -u "$unit" --no-pager --lines=15 -o cat 2>/dev/null || true)"
          printf '🔴 unit failed on %s: %s\n\n%s\n\n--- recent logs ---\n%s' \
            "$host" "$unit" "$status" "$logs" | ${lib.getExe matrixAlertPost}
        '';
      };

      # Disk-usage guard: post if any local filesystem is ≥ 90% full. Host-direct
      # on purpose — a disk-full alert must not depend on OpenObserve, which
      # lives on this host's storage.
      alert-disk-space = {
        description = "Alert Matrix when a local filesystem is ≥90% full";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.coreutils
          pkgs.gawk
        ];
        script = ''
          threshold=90
          host="$(uname -n)"
          # Local, real filesystems only (skip pseudo/virtual mounts). df prints
          # use% first; strip the '%' and compare numerically.
          offenders="$(df -P -l \
              -x tmpfs -x devtmpfs -x overlay -x squashfs -x ramfs \
              --output=pcent,size,used,avail,target 2>/dev/null \
            | awk 'NR>1 { p=$1; gsub("%","",p); if (p+0 >= '"$threshold"') print }')"
          if [ -n "$offenders" ]; then
            printf '🟠 disk usage ≥%s%% on %s\n\n%s' \
              "$threshold" "$host" "$offenders" | ${lib.getExe matrixAlertPost}
          fi
        '';
      };
    };

  systemd.timers.alert-disk-space = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "1h";
      Unit = "alert-disk-space.service";
    };
  };
}
