# Stalwart 0.16 configuration for beefcake.
#
# Uses our custom module (lib/modules/nixos/stalwart.nix) which replaces the
# upstream nixpkgs services.stalwart (incompatible with 0.16's config model).
# All field formats below were validated against a live 0.16.8 sandbox —
# see the module header for the encoding rules (sets as maps, clientId, etc).
#
# Migration runbook: issues/open/stalwart-0.16-upgrade.md
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
  credsDir = "/run/credentials/stalwart.service";
  httpPort = 38181;
in
{
  # Disable the upstream module — it generates TOML config which 0.16 ignores.
  disabledModules = [ "services/mail/stalwart.nix" ];

  # Pull in our replacement module.
  imports = [ ../../../lib/modules/nixos/stalwart.nix ];

  systemd.tmpfiles.settings."10-stalwart" = {
    ${dataDir} = {
      "d" = {
        mode = "0750";
        user = "stalwart";
        group = "stalwart";
      };
    };
    ${certDir} = {
      "d" = {
        mode = "0700";
        user = "stalwart";
        group = "stalwart";
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

  # --- Stalwart service ---

  services.stalwart = {
    enable = true;

    user = "stalwart";
    group = "stalwart";

    dataDir = dataDir;
    openFirewall = false;

    firewallPorts = [
      25
      465
      587
      993
    ];

    credentials = {
      admin_password = config.sops.secrets.stalwart-admin-password.path;
      smtp_relay_username = config.sops.secrets.stalwart-smtp-relay-username.path;
      smtp_relay_password = config.sops.secrets.stalwart-smtp-relay-password.path;
      dkim_private_key = config.sops.secrets.stalwart-dkim-private-key.path;
    };

    # Fallback admin — lets stalwart-cli apply authenticate even before the
    # DB has a real admin account (first boot after migration).
    recoveryAdminCredential = "admin_password";

    storeConfig = {
      "@type" = "RocksDb";
      path = "${dataDir}/rocksdb";
    };

    applyUrl = "http://[::1]:${toString httpPort}";
    applyAdminUser = "admin";
    applyAdminPasswordCredential = "admin_password";

    # The apply service ensures these exist and substitutes @DOMAIN_ID@ /
    # @CERT_ID@ into the plan (JMAP #refs are broken for Certificate ids
    # in 0.16.8, and create-if-exists cascades break refs on re-apply).
    domain = domain;
    certificateFiles = {
      certificate = "${certDir}/fullchain.pem";
      privateKey = "${certDir}/privkey.pem";
    };

    # The relay username is a sops secret; File refs aren't supported for
    # authUsername (plain string field), so it's substituted at apply time.
    planSubstitutions."@SMTP_RELAY_USERNAME@" = "smtp_relay_username";

    # Dashboard access for daniel@lyte.dev (accounts are user data, so the
    # role is granted by name lookup at apply time, not as a plan op).
    adminAccounts = [ "daniel" ];

    # --- Declarative plan ---
    #
    # Re-applied idempotently on every switch.  Owned types (listeners,
    # DKIM, routes, OAuth clients) are destroyed and re-created; singletons
    # (SystemSettings, MtaOutboundStrategy) are updated.
    #
    # NOTE: listener changes only take effect after stalwart.service
    # restarts — apply updates the DB, not live sockets.
    plan = [
      {
        "@type" = "update";
        object = "SystemSettings";
        value = {
          defaultHostname = host;
          defaultDomainId = "@DOMAIN_ID@";
          defaultCertificateId = "@CERT_ID@";
        };
      }

      # ---- Logging to journald ----
      # 0.16 stores tracer config in the DB; without this the server logs
      # nothing (the 0.15 stdout tracer was in the wiped TOML settings).
      {
        "@type" = "destroy";
        object = "Tracer";
        value = { };
      }
      {
        "@type" = "create";
        object = "Tracer";
        value.stdout = {
          "@type" = "Stdout";
          enable = true;
          ansi = false;
          level = "info";
        };
      }

      # ---- Network listeners ----
      {
        "@type" = "destroy";
        object = "NetworkListener";
        value = { };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.smtp = {
          name = "smtp";
          protocol = "smtp";
          bind."[::]:25" = true;
          useTls = false;
        };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.submissions = {
          name = "submissions";
          protocol = "smtp";
          bind."[::]:465" = true;
          useTls = true;
          tlsImplicit = true;
        };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.submission = {
          name = "submission";
          protocol = "smtp";
          bind."[::]:587" = true;
          useTls = true;
          tlsImplicit = false;
        };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.imaps = {
          name = "imaps";
          protocol = "imap";
          bind."[::]:993" = true;
          useTls = true;
          tlsImplicit = true;
        };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.jmap = {
          name = "jmap";
          protocol = "http";
          bind = {
            "[::1]:${toString httpPort}" = true;
            "127.0.0.1:${toString httpPort}" = true;
          };
          useTls = false;
        };
      }

      # ---- DKIM signing ----
      {
        "@type" = "destroy";
        object = "DkimSignature";
        value = { };
      }
      {
        "@type" = "create";
        object = "DkimSignature";
        value."dkim-lyte" = {
          "@type" = "Dkim1RsaSha256";
          domainId = "@DOMAIN_ID@";
          selector = "stalwart";
          privateKey = {
            "@type" = "File";
            filePath = "${credsDir}/dkim_private_key";
          };
          headers = {
            "From" = true;
            "To" = true;
            "Date" = true;
            "Subject" = true;
            "Message-ID" = true;
          };
          canonicalization = "relaxed/relaxed";
          report = true;
        };
      }

      # ---- Outbound routing ----
      {
        "@type" = "destroy";
        object = "MtaRoute";
        value = { };
      }
      {
        "@type" = "create";
        object = "MtaRoute";
        value.local = {
          "@type" = "Local";
          name = "local";
        };
      }
      {
        "@type" = "create";
        object = "MtaRoute";
        value.relay = {
          "@type" = "Relay";
          name = "relay";
          address = "smtp.mailgun.org";
          port = 587;
          implicitTls = false;
          authUsername = "@SMTP_RELAY_USERNAME@";
          authSecret = {
            "@type" = "File";
            filePath = "${credsDir}/smtp_relay_password";
          };
        };
      }

      # Local domains deliver locally, everything else goes to the relay
      # (replaces 0.15's queue.strategy.route expressions; default would
      # otherwise be direct MX delivery).
      {
        "@type" = "update";
        object = "MtaOutboundStrategy";
        value.route = {
          match."0" = {
            "if" = "is_local_domain(rcpt_domain)";
            "then" = "'local'";
          };
          "else" = "'relay'";
        };
      }

      # ---- OAuth client for Bulwark webmail ----
      # Replaces the old curl-based stalwart-ensure-bulwark-oauth.service.
      {
        "@type" = "destroy";
        object = "OAuthClient";
        value = { };
      }
      {
        "@type" = "create";
        object = "OAuthClient";
        value."bulwark-webmail" = {
          clientId = "bulwark-webmail";
          description = "Bulwark webmail OAuth client";
          redirectUris."https://webmail.${domain}/api/auth/callback" = true;
        };
      }
    ];
  };

  # Attach cert-copy ordering to stalwart (not stalwart-mail — renamed in 26.05).
  systemd.services.stalwart = {
    after = [ "copy-stalwart-certificates-from-caddy.service" ];
    wants = [ "copy-stalwart-certificates-from-caddy.service" ];
  };

  # --- Certificate copy timer (unchanged from 0.15 setup) ---

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
      install -d -m 0700 -o stalwart -g stalwart ${certDir}
      if [ ! -d /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${host} ]; then
        echo "mail certificate not provisioned by Caddy yet, skipping copy"
        exit 0
      fi
      cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${host}
      changed=0
      cmp -s ${host}.crt ${certDir}/fullchain.pem || changed=1
      install -m 0600 -o stalwart -g stalwart ${host}.crt ${certDir}/fullchain.pem
      install -m 0600 -o stalwart -g stalwart ${host}.key ${certDir}/privkey.pem
      # Stalwart 0.16 stores the cert *content* in its DB — it only re-reads
      # these files when stalwart-apply runs. Re-apply on renewal so the
      # served certificate doesn't go stale (Caddy renews ~every 60 days).
      if [ "$changed" = 1 ] && systemctl is-active --quiet stalwart.service; then
        echo "certificate changed; re-running stalwart-apply to refresh DB copy"
        systemctl restart stalwart-apply.service || true
      fi
    '';
  };

  networking.firewall.allowedTCPPorts = [
    25
    465
    587
    993
  ];

  # No Caddy-side CORS: stalwart 0.16 emits its own Access-Control-* headers,
  # and duplicating Access-Control-Allow-Origin makes browsers reject the
  # response outright (this silently broke bulwark's OIDC discovery).
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
