{
  systemd.tmpfiles.settings = {
    "10-caddy" = {
      "/storage/files.lyte.dev" = {
        "d" = {
          mode = "2775";
          user = "root";
          group = "wheel";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/files.lyte.dev"
  ];
  services.caddy = {
    # TODO: 502 and other error pages
    enable = true;
    email = "daniel@lyte.dev";
    adapter = "caddyfile";
    virtualHosts = {
      "http://files.beefcake.hare-cod.ts.net" = {
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
      "http://files.beefcake.lan" = {
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
      "files.lyte.dev" = {
        # TODO: customize the files.lyte.dev template?
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
    };
    # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
