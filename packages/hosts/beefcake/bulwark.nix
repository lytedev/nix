{ config, pkgs, ... }:
let
  domain = "webmail.lyte.dev";
  port = 3000;
  clientId = "bulwark-webmail";
  stalwartUrl = "https://mail.lyte.dev";
  stalwartLocal = "http://[::1]:38181";
  adminCredsDir = "/run/credentials/stalwart-mail.service";
in
{
  sops.secrets."bulwark.env" = {
    mode = "0400";
  };

  # Ensure the Bulwark OAuth client principal exists in Stalwart
  systemd.services.stalwart-ensure-bulwark-oauth = {
    description = "Ensure Bulwark OAuth client exists in Stalwart";
    after = [ "stalwart-mail.service" ];
    requires = [ "stalwart-mail.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      curl
      jq
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      admin_pass="$(cat ${adminCredsDir}/admin_password)"

      # Wait for Stalwart to be ready (up to 60s)
      ready=false
      for i in $(seq 1 30); do
        if curl -sf "${stalwartLocal}/.well-known/openid-configuration" >/dev/null 2>&1; then
          ready=true
          break
        fi
        echo "Waiting for Stalwart to be ready... ($i/30)"
        sleep 2
      done

      if [ "$ready" != "true" ]; then
        echo "Stalwart not ready after 60s, will retry next boot"
        exit 0
      fi

      # Check if the OAuth client already exists
      existing=$(curl -sf -u "admin:$admin_pass" \
        "${stalwartLocal}/api/principal/${clientId}" 2>/dev/null || true)

      if [ -n "$existing" ] && echo "$existing" | jq -e '.data.name' >/dev/null 2>&1; then
        echo "OAuth client '${clientId}' already exists, skipping"
        exit 0
      fi

      echo "Creating OAuth client '${clientId}'..."
      curl -sf -u "admin:$admin_pass" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '${
          builtins.toJSON {
            type = "oauthClient";
            name = clientId;
            description = "Bulwark webmail OAuth client";
            urls = [ "https://${domain}/api/auth/callback" ];
          }
        }' \
        "${stalwartLocal}/api/principal" || echo "Failed to create OAuth client, will retry next boot"

      exit 0
    '';
  };

  virtualisation.oci-containers.containers.bulwark = {
    image = "ghcr.io/bulwarkmail/webmail:1.4.7";
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
      OAUTH_ISSUER_URL = stalwartUrl;
    };
  };

  services.caddy.virtualHosts.${domain} = {
    extraConfig = "reverse_proxy :${toString port}";
  };
}
