{
  config,
  lib,
  pkgs,
  ...
}:
{
  # nextcloud
  users.users.nextcloud = {
    isSystemUser = true;
    createHome = false;
    group = "nextcloud";
  };
  users.groups.nextcloud = { };
  sops.secrets = {
    nextcloud-admin-password = {
      owner = "nextcloud";
      group = "nextcloud";
      mode = "400";
    };
  };
  systemd.tmpfiles.settings = {
    "10-nextcloud" = {
      "/storage/nextcloud" = {
        "d" = {
          mode = "0750";
          user = "nextcloud";
          group = "nextcloud";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/nextcloud"
  ];
  services.postgresql = {
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
    ];
  };
  services.nextcloud = {
    enable = false;
    hostName = "nextcloud.h.lyte.dev";
    maxUploadSize = "100G";
    extraAppsEnable = true;
    autoUpdateApps.enable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit
        calendar
        contacts
        notes
        onlyoffice
        tasks
        ;
    };
    package = pkgs.nextcloud28;
    home = "/storage/nextcloud";
    configureRedis = true;
    caching.redis = true;
    settings = {
      # TODO: SMTP
      maintenance_window_start = 1;
    };
    config = {
      adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
      adminuser = "daniel";
      dbtype = "pgsql";
      dbhost = "/run/postgresql";
    };
    phpOptions = {
      "xdebug.mode" = "debug";
      "xdebug.client_host" = "10.0.2.2";
      "xdebug.client_port" = "9000";
      "xdebug.start_with_request" = "yes";
      "xdebug.idekey" = "ECLIPSE";
    };
  };
  services.nginx.enable = false;
  systemd.services.nextcloud = {
    serviceConfig.User = "nextcloud";
    serviceConfig.Group = "nextcloud";
  };

  services.phpfpm = lib.mkIf config.services.nextcloud.enable {
    pools.nextcloud.settings = {
      "listen.owner" = "caddy";
      "listen.group" = "caddy";
    };
  };

  services.caddy.virtualHosts."nextcloud.h.lyte.dev" =
    let
      fpm-nextcloud-pool = config.services.phpfpm.pools.nextcloud;
      root = config.services.nginx.virtualHosts.${config.services.nextcloud.hostName}.root;
    in
    lib.mkIf config.services.nextcloud.enable {
      extraConfig = ''
        encode zstd gzip

        root * ${root}

        redir /.well-known/carddav /remote.php/dav 301
        redir /.well-known/caldav /remote.php/dav 301
        redir /.well-known/* /index.php{uri} 301
        redir /remote/* /remote.php{uri} 301

        header {
          Strict-Transport-Security max-age=31536000
          Permissions-Policy interest-cohort=()
          X-Content-Type-Options nosniff
          X-Frame-Options SAMEORIGIN
          Referrer-Policy no-referrer
          X-XSS-Protection "1; mode=block"
          X-Permitted-Cross-Domain-Policies none
          X-Robots-Tag "noindex, nofollow"
          X-Forwarded-Host nextcloud.h.lyte.dev
          -X-Powered-By
        }

        php_fastcgi unix/${fpm-nextcloud-pool.socket} {
          root ${root}
          env front_controller_active true
          env modHeadersAvailable true
        }

        @forbidden {
          path /build/* /tests/* /config/* /lib/* /3rdparty/* /templates/* /data/*
          path /.* /autotest* /occ* /issue* /indie* /db_* /console*
          not path /.well-known/*
        }
        error @forbidden 404

        @immutable {
          path *.css *.js *.mjs *.svg *.gif *.png *.jpg *.ico *.wasm *.tflite
          query v=*
        }
        header @immutable Cache-Control "max-age=15778463, immutable"

        @static {
          path *.css *.js *.mjs *.svg *.gif *.png *.jpg *.ico *.wasm *.tflite
          not query v=*
        }
        header @static Cache-Control "max-age=15778463"

        @woff2 path *.woff2
        header @woff2 Cache-Control "max-age=604800"

        file_server
      '';
    };
}
