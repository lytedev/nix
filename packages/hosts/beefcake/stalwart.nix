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
  # In 26.05 the module names the systemd unit "stalwart.service" (the User/Group
  # stay "stalwart-mail" via stateVersion=25.11, but the unit itself is renamed),
  # so LoadCredential exposes secrets under /run/credentials/stalwart.service.
  credsDir = "/run/credentials/stalwart.service";
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
    stalwart-smtp-relay-username.mode = "0400";
    stalwart-smtp-relay-password.mode = "0400";
    stalwart-dkim-private-key.mode = "0400";
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
    # First enabled during the 25.11 cycle (2026-03-19). Pin to 25.11 so the
    # 26.05 module keeps the legacy "stalwart-mail" user/group and storage layout
    # (StateDirectory, data ownership) rather than switching to "stalwart". NOTE:
    # the systemd *unit* is still renamed to "stalwart.service" regardless of this.
    stateVersion = "25.11";
    openFirewall = false;
    dataDir = dataDir;
    credentials = {
      admin_password = config.sops.secrets.stalwart-admin-password.path;
      smtp_relay_username = config.sops.secrets.stalwart-smtp-relay-username.path;
      smtp_relay_password = config.sops.secrets.stalwart-smtp-relay-password.path;
      dkim_private_key = config.sops.secrets.stalwart-dkim-private-key.path;
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
        cert = "%{file:${certDir}/fullchain.pem}%";
        private-key = "%{file:${certDir}/privkey.pem}%";
      };

      store.rocksdb = {
        type = "rocksdb";
        path = "${dataDir}/rocksdb";
        compression = "lz4";
      };

      # All logical stores live in the single embedded RocksDB store, which holds
      # the ~15GB of mail today. This is the recommended single-node layout.
      #
      # Possible future optimization if folder/search performance ever needs more:
      # split `fts` out to a dedicated full-text backend (Meilisearch / Elastic /
      # PostgreSQL) so search load doesn't compete with mail data in RocksDB. That
      # would be a data migration (reindex), so it's deliberately deferred — the
      # cache tuning below is the cheaper, no-migration win to try first.
      storage = {
        data = "rocksdb";
        fts = "rocksdb";
        blob = "rocksdb";
        lookup = "rocksdb";
        directory = "internal";
      };

      # Performance tuning. The message-metadata cache (per-account UIDs, flags,
      # mailbox state) is the single biggest lever for IMAP folder-load latency:
      # it's consulted on every folder listing, sync, new-mail check, and flag
      # update. Stalwart's default is only 50mb, which thrashes on large/bloated
      # folders. beefcake has ~250GB RAM, so size it generously to keep all
      # connected users' metadata resident and avoid round-trips to the store.
      # See https://stalw.art/docs/server/cache/ and /docs/install/performance/.
      cache.messages = "1gb";
      cache.accounts = "128mb";
      cache.emailAddresses = "32mb";

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

      queue.strategy.route."0000" = {
        "if" = "is_local_domain('', rcpt_domain)";
        "then" = "'local'";
      };
      queue.strategy.route."0001"."else" = "'relay'";

      queue.route.local.type = "local";
      queue.route.relay.type = "relay";
      queue.route.relay.address = "smtp.mailgun.org";
      queue.route.relay.port = 587;
      queue.route.relay.protocol = "smtp";
      queue.route.relay.tls.enable = true;
      queue.route.relay.tls.implicit = false;
      queue.route.relay.auth.username = "%{file:${credsDir}/smtp_relay_username}%";
      queue.route.relay.auth.secret = "%{file:${credsDir}/smtp_relay_password}%";

      # Auto-create Archive mailbox for all accounts (needed for Bulwark archive action)
      email.folders.archive = {
        name = "Archive";
        create = true;
        subscribe = true;
      };

      # DKIM signing
      signature.dkim-lyte = {
        algorithm = "rsa-sha256";
        domain = domain;
        selector = "'stalwart'";
        private-key = "%{file:${credsDir}/dkim_private_key}%";
        headers = "['From', 'To', 'Date', 'Subject', 'Message-ID']";
        canonicalization = "'relaxed/relaxed'";
        set-body-length = false;
        report = true;
      };
      auth.dkim.sign = "['dkim-lyte']";
    };
  };

  # The 26.05 module defines the unit as "stalwart.service" (not "stalwart-mail").
  # Attach the cert-copy ordering to the real unit; targeting "stalwart-mail" here
  # would create a phantom ExecStart-less unit and leave mail down.
  systemd.services.stalwart = {
    after = [
      "copy-stalwart-certificates-from-caddy.service"
    ];
    wants = [
      "copy-stalwart-certificates-from-caddy.service"
    ];
  };

  services.caddy.virtualHosts.${host} = {
    extraConfig = ''
      @cors_preflight method OPTIONS
      @cors_webmail header Origin https://webmail.${domain}

      handle @cors_preflight {
        header Access-Control-Allow-Origin "https://webmail.${domain}"
        header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        header Access-Control-Allow-Headers "Content-Type, Authorization"
        header Access-Control-Allow-Credentials "true"
        header Access-Control-Max-Age "86400"
        respond "" 204
      }

      reverse_proxy [::1]:${toString httpPort} {
        header_up Host {host}
        header_up X-Real-Ip {remote_host}
        header_up -X-Forwarded-For
        header_up -X-Forwarded-Host
        header_up -X-Forwarded-Proto
      }

      header @cors_webmail Access-Control-Allow-Origin "https://webmail.${domain}"
      header @cors_webmail Access-Control-Allow-Credentials "true"
    '';
  };
}
