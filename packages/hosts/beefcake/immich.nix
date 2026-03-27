# Immich — self-hosted photo/video backup
#
# Web UI: https://photos.lyte.dev
# SSO:    Kanidm OIDC via kanidm-oauth2-secrets fetcher (automatic)
# Media:  /storage/immich (ZFS, backed up via restic)
{ config, pkgs, ... }:
let
  domain = "photos.lyte.dev";
  port = 2283;
in
{
  # ── Storage (ZFS pool) ──────────────────────────────────────────────
  systemd.tmpfiles.settings = {
    "10-immich" = {
      "/storage/immich" = {
        "d" = {
          mode = "0750";
          user = "immich";
          group = "immich";
        };
      };
    };
  };

  # ── Backup ──────────────────────────────────────────────────────────
  services.restic.commonPaths = [
    "/storage/immich"
  ];

  # ── OAuth2 secret from Kanidm (auto-fetched) ───────────────────────
  lyte.kanidm-oauth2-secrets.secrets.immich-oauth = {
    client = domain;
    owner = "immich";
    group = "immich";
  };

  # Ensure immich starts after secrets are fetched
  systemd.services.immich-server = {
    after = [ "kanidm-oauth2-secrets.service" ];
    wants = [ "kanidm-oauth2-secrets.service" ];
  };

  # ── Immich service ──────────────────────────────────────────────────
  services.immich = {
    enable = true;
    inherit port;
    mediaLocation = "/storage/immich";
    database.enableVectors = false; # pgvecto.rs doesn't support PG17
    database.enableVectorChord = true; # VectorChord does — keeps smart search + face clustering

    # Immich manages its own database inside the system-wide PostgreSQL instance.

    settings = {
      oauth = {
        enabled = true;
        issuerUrl = "https://idm.h.lyte.dev/oauth2/openid/${domain}/.well-known/openid-configuration";
        clientId = domain;
        clientSecret._secret = "/run/kanidm-oauth2-secrets/immich-oauth.secret";
        mobileRedirectUri = "https://${domain}/api/oauth/mobile-redirect";
        scope = "openid profile email";
        autoRegister = true;
        buttonText = "Login with Kanidm";
      };
      server.externalDomain = "https://${domain}";
    };
  };

  # Let immich access GPU for ML inference (if hardware is present)
  users.users.immich.extraGroups = [
    "video"
    "render"
  ];

  # ── Ensure mobile OAuth redirect URIs are registered in Kanidm ──────
  # Kanidm's HJSON migration rejects opaque URIs like app.immich://,
  # so we add them imperatively after Kanidm starts. This is additive
  # and idempotent — existing URIs are preserved.
  systemd.services.immich-ensure-mobile-oauth = {
    description = "Register Immich mobile OAuth redirect URIs in Kanidm";
    after = [ "kanidm.service" ];
    wants = [ "kanidm.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.kanidm ];
    script = ''
      # Wait for Kanidm to be ready
      for i in $(seq 1 30); do
        if curl -sf https://idm.h.lyte.dev/status >/dev/null 2>&1; then
          break
        fi
        echo "Waiting for Kanidm... ($i/30)"
        sleep 2
      done

      export KANIDM_TOKEN=$(cat /run/secrets/kanidm-host-beefcake-token)

      for url in \
        "https://${domain}/user-settings" \
        "https://${domain}/api/oauth/mobile-redirect" \
        "app.immich:/" \
        "app.immich:///oauth-callback"; do
        echo "Ensuring redirect URL: $url"
        kanidm system oauth2 add-redirect-url ${domain} "$url" \
          --url https://idm.h.lyte.dev 2>&1 || true
      done

      exit 0
    '';
  };

  systemd.timers.immich-ensure-mobile-oauth = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      Unit = "immich-ensure-mobile-oauth.service";
    };
  };

  # ── Caddy reverse proxy ─────────────────────────────────────────────
  services.caddy.virtualHosts.${domain} = {
    extraConfig = ''
      reverse_proxy [::1]:${toString port} {
        header_up X-Real-Ip {remote_host}
      }
    '';
  };
}
