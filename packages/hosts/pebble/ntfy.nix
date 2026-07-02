# Self-hosted ntfy on pebble — the private push channel for the off-site uptime
# watcher (Tier 0 in lib/doc/alerting.md).
#
# WHY HERE: the val.town watcher needs a push channel that does NOT depend on
# beefcake (so it still fires when beefcake is down). ntfy.sh (hosted) works but
# reserving/locking a topic is a paid feature, so an unauthenticated public
# topic is the only free option there. Self-hosting ntfy gives topic auth for
# free, and pebble is the right host: external (Hetzner, static IP), already in
# the fleet, and independent of beefcake. Footprint is tiny (~20 MB RSS).
#
# EXPOSURE: adds Caddy + public :80/:443 to pebble (previously DNS/mail only).
# ntfy binds loopback; Caddy terminates TLS (Let's Encrypt HTTP-01 — pebble has
# a public IP and ntfy.e.lyte.dev resolves to it) and reverse-proxies it.
# auth-default-access = deny-all, so only the provisioned `alerts` user can
# touch any topic.
#
# ONE-TIME BOOTSTRAP (before deploying — activation needs the secret):
#   Seed the pebble sops file with the env-file line the service reads:
#     nix develop -c sops secrets/pebble/secrets.yml
#   add, verbatim (KEY=VALUE — this file is used as a systemd EnvironmentFile):
#     ntfy-env: |
#       ALERTS_PASSWORD=<a long random password>
#   The same password is set on the val (NTFY_USER=alerts, NTFY_PASSWORD=…) so
#   it can publish, and entered in the phone's ntfy app to subscribe.
{
  config,
  pkgs,
  ...
}:
let
  topic = "infra-alerts";
  authFile = "/var/lib/ntfy-sh/user.db";
  ntfy = "${config.services.ntfy-sh.package}/bin/ntfy";

  # Idempotent auth provisioning. Runs as ExecStartPost of the ntfy-sh unit, so
  # it inherits the unit's (Dynamic)User, StateDirectory, and the EnvironmentFile
  # (-> $ALERTS_PASSWORD). Operates directly on the auth-file via the CLI; the
  # NTFY_AUTH_* env vars point the CLI at the same DB the server uses.
  provision = pkgs.writeShellScript "ntfy-provision" ''
    set -eu
    export NTFY_AUTH_FILE=${authFile}
    export NTFY_AUTH_DEFAULT_ACCESS=deny-all
    # The server creates the auth-file on startup, and ExecStartPost can fire
    # before that finishes — the CLI refuses to touch a missing auth-file ("please
    # start the server at least once to create it"), which would fail the whole
    # unit. Wait for it to appear (up to ~30s) first.
    for _ in $(seq 1 60); do
      [ -f "${authFile}" ] && break
      sleep 0.5
    done
    # Create the publisher/subscriber user once (no-op if it already exists; the
    # password is set only at creation — rotate with `ntfy user change-pass`).
    NTFY_PASSWORD="$ALERTS_PASSWORD" ${ntfy} user add --ignore-exists alerts
    # (Re)assert access every start so the grant survives DB edits.
    ${ntfy} access alerts ${topic} read-write
  '';
in
{
  sops.secrets."ntfy-env".mode = "0400"; # systemd reads it as root for EnvironmentFile

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.e.lyte.dev";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-file = authFile;
      auth-default-access = "deny-all";
      cache-file = "/var/lib/ntfy-sh/cache.db";
    };
    environmentFile = config.sops.secrets."ntfy-env".path;
  };

  systemd.services.ntfy-sh.serviceConfig.ExecStartPost = [ provision ];

  # TLS edge for ntfy. HTTP-01 via the public IP (no DNS-01/TSIG needed like
  # beefcake); reverse-proxies the loopback ntfy listener.
  services.caddy = {
    enable = true;
    email = "daniel@lyte.dev";
    virtualHosts."ntfy.e.lyte.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:2586
    '';
  };

  # Merges with pebble.nix's existing allowedTCPPorts ([22 25 53]).
  networking.firewall.allowedTCPPorts = [
    80 # ACME HTTP-01 + redirect
    443 # ntfy via Caddy
  ];
}
