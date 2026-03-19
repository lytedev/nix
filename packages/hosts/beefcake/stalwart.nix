{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "lyte.dev";
  host = "mail.${domain}";
  dataDir = "/storage/stalwart";
  certDir = "${dataDir}/certs";
  credsDir = "/run/credentials/stalwart-mail.service";
  httpPort = 38181;
in
{
  systemd.tmpfiles.settings."10-stalwart" = {
    ${dataDir} = {
      "d" = {
        mode = "0750";
        user = "stalwart-mail";
        group = "stalwart-mail";
      };
    };
    ${certDir} = {
      "d" = {
        mode = "0700";
        user = "stalwart-mail";
        group = "stalwart-mail";
      };
    };
  };

  services.restic.commonPaths = [ dataDir ];

  sops.secrets = {
    stalwart-admin-password.mode = "0400";
    stalwart-mailgun-password.mode = "0400";
  };

  # Copy the mail certificate that Caddy provisions so Stalwart can terminate
  # TLS directly on IMAPS / SMTPS / Submission.
  systemd.timers."copy-stalwart-certificates-from-caddy" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      Unit = "copy-stalwart-certificates-from-caddy.service";
    };
  };

  systemd.services."copy-stalwart-certificates-from-caddy" = {
    after = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
      "caddy.service"
    ];
    path = with pkgs; [ coreutils ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -euo pipefail
      umask 077
      install -d -m 0700 -o stalwart-mail -g stalwart-mail ${certDir}
      if [ ! -d /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${host} ]; then
        echo "mail certificate not provisioned by Caddy yet, skipping copy"
        exit 0
      fi
      cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${host}
      install -m 0600 -o stalwart-mail -g stalwart-mail ${host}.crt ${certDir}/fullchain.pem
      install -m 0600 -o stalwart-mail -g stalwart-mail ${host}.key ${certDir}/privkey.pem
    '';
  };

  networking.firewall.allowedTCPPorts = [
    25
    465
    587
    993
  ];

  services.stalwart-mail = {
    enable = true;
    openFirewall = false;
    dataDir = dataDir;
    credentials = {
      admin_password = config.sops.secrets.stalwart-admin-password.path;
      mailgun_password = config.sops.secrets.stalwart-mailgun-password.path;
    };
    settings = {
      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:${credsDir}/admin_password}%";
      };

      server = {
        hostname = host;
        tls = {
          enable = true;
          implicit = true;
          certificate = "caddy";
        };
        listener = {
          smtp = {
            bind = [ "[::]:25" ];
            protocol = "smtp";
          };
          submissions = {
            bind = [ "[::]:465" ];
            protocol = "smtp";
            tls.implicit = true;
          };
          submission = {
            bind = [ "[::]:587" ];
            protocol = "smtp";
          };
          imaps = {
            bind = [ "[::]:993" ];
            protocol = "imap";
            tls.implicit = true;
          };
          jmap = {
            bind = [
              "[::1]:${toString httpPort}"
              "127.0.0.1:${toString httpPort}"
            ];
            protocol = "http";
          };
        };
      };

      http = {
        url = "'https://${host}'";
        use-x-forwarded = false;
      };

      certificate.caddy = {
        cert = "file://${certDir}/fullchain.pem";
        private-key = "file://${certDir}/privkey.pem";
      };

      store.rocksdb = {
        type = "rocksdb";
        path = "${dataDir}/rocksdb";
        compression = "lz4";
      };

      storage = {
        data = "rocksdb";
        fts = "rocksdb";
        blob = "rocksdb";
        lookup = "rocksdb";
        directory = "internal";
      };

      lookup.default = {
        hostname = host;
        domain = domain;
      };

      directory.internal = {
        type = "internal";
        store = "rocksdb";
      };

      session.auth = {
        mechanisms = "[plain]";
        directory = "'internal'";
      };
      session.rcpt.directory = "'internal'";
      session.auth.must-match-sender = false;

      queue.strategy.route = [ { "else" = "'relay'"; } ];
      remote.relay = {
        type = "relay";
        address = "smtp.mailgun.org";
        port = 587;
        protocol = "smtp";
        tls = {
          enable = true;
          implicit = false;
        };
        auth = {
          username = "grafana@lyte.dev";
          secret = "%{file:${credsDir}/mailgun_password}%";
        };
      };
    };
  };

  systemd.services.stalwart-mail = {
    after = [
      "copy-stalwart-certificates-from-caddy.service"
    ];
    wants = [
      "copy-stalwart-certificates-from-caddy.service"
    ];
  };

  services.caddy.virtualHosts.${host} = {
    extraConfig = ''
      reverse_proxy [::1]:${toString httpPort} {
        header_up Host {host}
        header_up X-Real-Ip {remote_host}
        header_up -X-Forwarded-For
        header_up -X-Forwarded-Host
        header_up -X-Forwarded-Proto
      }
    '';
  };
}
