{ config, pkgs, ... }:
let
  domain = "webmail.lyte.dev";
  port = 3000;
  clientId = "bulwark-webmail";
  stalwartUrl = "https://mail.lyte.dev";
  # Kanidm OIDC issuer for the bulwark-webmail public client (PKCE code
  # flow). Stalwart accepts the resulting tokens via its "kanidm" Oidc
  # directory (see ./stalwart.nix) — JMAP still goes to stalwart.
  kanidmIssuerUrl = "https://idm.h.lyte.dev/oauth2/openid/${clientId}";
in
{
  sops.secrets."bulwark.env" = {
    mode = "0400";
  };

  # OAuth client provisioning is now handled declaratively in the stalwart
  # plan (beefcake/stalwart.nix) via stalwart-cli apply.  The old
  # stalwart-ensure-bulwark-oauth curl service is removed.

  virtualisation.oci-containers.containers.bulwark = {
    image = "ghcr.io/bulwarkmail/webmail:1.7.7@sha256:8c93a6af6abf1b0e6595015dd8236ad83c4cbb2a1dce51966deaecb4d93ffeea";
    autoStart = true;
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
    # The host maps idm.h.lyte.dev -> ::1 (kanidm.nix extraHosts, for
    # host-local clients). Podman copies host /etc/hosts entries into the
    # container, where ::1 is the container's own loopback — bulwark's
    # server-side OIDC discovery/token exchange against Kanidm got
    # Connection refused (--add-host can't fix it: the ::1 entry still wins
    # resolution). LAN DNS already answers correctly for idm/mail/webmail,
    # so drop the inherited hosts file and resolve via DNS only.
    extraOptions = [ "--no-hosts" ];
    environmentFiles = [
      config.sops.secrets."bulwark.env".path
    ];
    environment = {
      JMAP_SERVER_URL = stalwartUrl;
      HOSTNAME = "0.0.0.0";
      PORT = toString port;
      OAUTH_ENABLED = "true";
      OAUTH_CLIENT_ID = clientId;
      OAUTH_ISSUER_URL = kanidmIssuerUrl;
      # Bulwark's SSRF guard rejects OAuth discovery endpoints whose hostname
      # resolves to an RFC1918 address. With LAN split-horizon DNS,
      # idm.h.lyte.dev (like mail.lyte.dev before it) resolves to a private
      # address inside the container, so the discovered token_endpoint gets
      # rejected as "non-public", logins fall
      # through to slow fallback paths, and webmail feels broken. This flag
      # short-circuits the guard for the configured OAuth issuer only (custom
      # JMAP endpoints supplied by users still get the check).
      # https://github.com/bulwarkmail/webmail/blob/00b40fc48a7fcd43fa65f21b94b42bda70102546/lib/oauth/token-exchange.ts#L9-L17
      OAUTH_ALLOW_PRIVATE_ENDPOINTS = "true";

      # The installed Android PWA showed white status/nav bars: they were the
      # OS chrome painted with the PWA's theme color, which was white. Bulwark's
      # default PWA_THEME_COLOR / PWA_BACKGROUND_COLOR are #ffffff and feed both
      # the web app manifest (theme_color/background_color) and the
      # <meta name="theme-color"> tag — so the system bars rendered white even
      # though the app itself paints its dark theme (whose --color-background is
      # #0a0a0a, see the served /_next CSS ".dark" rule). Match that dark chrome
      # so the bars blend into the app instead of framing it in white.
      # Docs: https://bulwarkmail.org/docs/features/pwa (PWA_THEME_COLOR example).
      # NOTE: the installed PWA caches the manifest — after deploying, the app
      # must be uninstalled and reinstalled on-device for this to take effect.
      PWA_THEME_COLOR = "#0a0a0a";
      PWA_BACKGROUND_COLOR = "#0a0a0a";
    };
  };

  services.caddy.virtualHosts.${domain} = {
    extraConfig = "reverse_proxy :${toString port}";
  };
}
