# Disk-health alerts → Matrix.
#
# smartd (SMART pre-failure / failed self-tests) and the ZFS Event Daemon
# (ZED: pool faults, vdev DEGRADED/FAULTED, spare activation, scrub/resilver
# errors) both already run on beefcake but, by default, notify nobody — which
# is why sde's "impending failure" SMART status and the Jun 1 spare activation
# went unnoticed. This wires both to post to a matrix-hookshot generic webhook,
# the same mechanism jmap-matrix-notify uses (no dedicated bot/appservice;
# hookshot is already registered with tuwunel).
#
# Deliberately a host-direct push rather than an OpenObserve alert rule:
#   - OpenObserve's alert rules live in its UI/DB, not in this repo, so an OO
#     rule would not be code-reviewable or reproducible here.
#   - OO stores its data on this very pool/host, so routing disk-failure alerts
#     through it is the wrong dependency exactly when the disks are the problem.
#
# One-time bootstrap (mint the webhook, then seed sops):
#   1. In the target Matrix room, invite hookshot and run:
#        !hookshot webhook disk-alerts
#      Copy the generated https://hookshot.matrix.lyte.dev/webhook/<uuid> URL.
#   2. Add it to secrets/beefcake/secrets.yml under `disk-alert-webhook-url`:
#        nix develop -c sops secrets/beefcake/secrets.yml
#   3. Deploy, then prove it end-to-end (either path posts to the room):
#        smartctl -t short /dev/sde      # smartd reports the result
#        zpool scrub zstorage            # ZED reports completion (verbose)
{
  config,
  pkgs,
  lib,
  ...
}:
let
  webhookSecret = config.sops.secrets.disk-alert-webhook-url.path;

  # Invoked by smartd (as notifications.mail.mailer, i.e. `<prog> -i <recipient>`)
  # and by ZED (as ZED_EMAIL_PROG). All CLI args are ignored; the alert text
  # arrives on stdin. Best-effort: it must never fail its caller.
  diskAlertNotify = pkgs.writeShellApplication {
    name = "disk-alert-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      webhook="$(cat ${webhookSecret} 2>/dev/null || true)"
      if [ -z "$webhook" ]; then
        echo "disk-alert-notify: no webhook url available" >&2
        exit 0
      fi
      host="$(uname -n)"
      body="$(cat || true)"
      text="$(printf '🔴 disk-alert on %s\n\n%s' "$host" "$body")"
      text="''${text:0:3500}"
      payload="$(jq -n --arg t "$text" '{text: $t}')"
      curl --fail --silent --show-error --max-time 20 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        "$webhook" >/dev/null || echo "disk-alert-notify: post failed" >&2
    '';
  };
in
{
  sops.secrets.disk-alert-webhook-url = {
    mode = "0400";
    # owner defaults to root; both smartd and zed run as root.
  };

  # smartd already runs (default-module.nix enables it). Route its notification
  # mail through the webhook poster; smartd calls `<mailer> -i <recipient>` with
  # the message on stdin. `defaults.monitored` (upstream default) already runs a
  # short self-test daily + long weekly and monitors SMART health/attributes.
  services.smartd.notifications.mail = {
    enable = true;
    recipient = "root";
    mailer = lib.getExe diskAlertNotify;
  };

  # ZED: enable notifications, but point the "mail program" at the webhook
  # poster. ZED runs `$ZED_EMAIL_PROG $ZED_EMAIL_OPTS` with the message on stdin;
  # @ADDRESS@ expands to ZED_EMAIL_ADDR (ignored by our script).
  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ "root" ];
    ZED_EMAIL_PROG = lib.getExe diskAlertNotify;
    ZED_EMAIL_OPTS = "@ADDRESS@";
    ZED_NOTIFY_VERBOSE = true;
  };
}
