{
  pkgs,
  ...
}:
{
  services.caddy = {
    virtualHosts = {
      "element.lyte.dev" = {
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            ## Access-Control-Allow-Credentials true
            ## Access-Control-Allow-Methods *
            ## Access-Control-Allow-Headers *
            ## Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root ${pkgs.element-web}/
          }

          handle /config.json {
            root * ${./element-web}
            file_server
          }
        '';
      };
    };
    # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };
}
