let
  domain = "webmail.lyte.dev";
  port = 3000;
in
{
  virtualisation.oci-containers.containers.bulwark = {
    image = "ghcr.io/bulwarkmail/webmail:1.4.7";
    autoStart = true;
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
    environment = {
      JMAP_SERVER_URL = "https://mail.lyte.dev";
      HOSTNAME = "0.0.0.0";
      PORT = toString port;
    };
  };

  services.caddy.virtualHosts.${domain} = {
    extraConfig = "reverse_proxy :${toString port}";
  };
}
