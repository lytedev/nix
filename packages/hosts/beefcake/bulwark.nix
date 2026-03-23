{ config, ... }:
let
  domain = "webmail.lyte.dev";
  port = 3000;
in
{
  sops.secrets."bulwark.env" = {
    mode = "0400";
    # Contains: SESSION_SECRET, OAUTH_CLIENT_SECRET (if confidential client)
  };

  virtualisation.oci-containers.containers.bulwark = {
    image = "ghcr.io/bulwarkmail/webmail:1.4.7";
    autoStart = true;
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
    environmentFiles = [
      config.sops.secrets."bulwark.env".path
    ];
    environment = {
      JMAP_SERVER_URL = "https://mail.lyte.dev";
      HOSTNAME = "0.0.0.0";
      PORT = toString port;
      OAUTH_ENABLED = "true";
      OAUTH_CLIENT_ID = "bulwark-webmail";
      OAUTH_ISSUER_URL = "https://mail.lyte.dev";
    };
  };

  services.caddy.virtualHosts.${domain} = {
    extraConfig = "reverse_proxy :${toString port}";
  };
}
