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
    image = "ghcr.io/bulwarkmail/webmail:1.7.2";
    autoStart = true;
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
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
    };
  };

  services.caddy.virtualHosts.${domain} = {
    extraConfig = "reverse_proxy :${toString port}";
  };
}
