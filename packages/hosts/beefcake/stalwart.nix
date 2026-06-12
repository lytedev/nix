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
          # pebble's HAProxy fronts the public MX and forwards with PROXY
          # protocol v2, so SPF/DNSBL/greylisting evaluate the true sender
          # IP instead of the relay's.
          #
          # SECURITY: trusting a network here means stalwart accepts a
          # PROXY header (which CLAIMS an arbitrary client IP) from any
          # source in it — i.e. that source can forge the sender IP and
          # defeat SPF/DNSBL/reputation. 100.64.0.0/10 is the WHOLE tailnet
          # CGNAT range, which is broader than the one legitimate proxy
          # (pebble). We deliberately rely on the headscale ACL as the
          # access-narrowing control: only `pebble` is permitted to reach
          # beefcake:25 (headscale-acl.json — `src: [pebble], dst:
          # [beefcake:25,2526]`), so in practice only pebble can present a
          # header here. The broad CIDR is chosen so this keeps working
          # across headscale IP reassignment; tightening to pebble's /32
          # would add defense-in-depth at the cost of breaking silently if
          # its tailnet IP churns. If the ACL is ever loosened, revisit this.
          #
          # NOTE: trusting a network also means stalwart *requires* a PROXY
          # header from it — plain SMTP from the tailnet to :25 deadlocks
          # waiting for the header. The fallback queue uses the separate
          # plain listener below (:2526) instead.
          overrideProxyTrustedNetworks."100.64.0.0/10" = true;
        };
      }
      {
        "@type" = "create";
        object = "NetworkListener";
        value.smtp-fallback = {
          name = "smtp-fallback";
          protocol = "smtp";
          # Plain SMTP for pebble's outage fallback queue (postfix can't
          # speak PROXY protocol outbound). Tailnet-firewalled (see
          # firewall.interfaces.tailscale0 below) — not publicly reachable.
          # Mail here arrives without the real sender IP (degraded SPF
          # fidelity), which only affects outage-window traffic.
          bind."[::]:2526" = true;
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

      # Require SMTP AUTH on submission ports but NOT the inbound MX ports.
      # Stalwart's default is `local_port != 25`; our outage-fallback
      # listener on 2526 (plain SMTP from pebble's queue) is also an inbound
      # MX path, so exempt it — otherwise stalwart demands auth at MAIL FROM
      # (503 "You must authenticate first") and the fallback can't deliver.
      {
        "@type" = "update";
        object = "MtaStageAuth";
        value.require = {
          match = { };
          "else" = "local_port != 25 && local_port != 2526";
        };
      }

      # ---- Spam allowlist: trusted lyte.dev senders ----
      # DMARC-verified mail from lyte.dev / *.lyte.dev gets the built-in
      # TRUSTED_DOMAIN tag (score -7), guaranteeing inbox delivery. The
      # DMARC guard prevents spoofed From:lyte.dev from bypassing the filter
      # (our own mail signs DKIM, so legit mail passes).
      #
      # Scoped destroy-by-name (NOT destroy-all): a filter value matches
      # only that rule, leaving stalwart's ~66 built-in SpamRules intact
      # (verified: a destroy with a non-matching name reports "0 destroyed").
      # This is how custom SpamRules stay declarative without a bespoke
      # ensure-by-name mechanism.
      {
        "@type" = "destroy";
        object = "SpamRule";
        value.name = "LYTEDEV_TRUSTED_DOMAIN";
      }
      {
        "@type" = "create";
        object = "SpamRule";
        value.lytedev-trusted = {
          "@type" = "Any";
          name = "LYTEDEV_TRUSTED_DOMAIN";
          description = "lyte.dev and subdomains are trusted (requires DMARC pass)";
          enable = true;
          priority = 100;
          condition = {
            match."0" = {
              "if" = "$DMARC_POLICY_ALLOW && (from.domain == 'lyte.dev' || ends_with(from.domain, '.lyte.dev'))";
              "then" = "'TRUSTED_DOMAIN'";
            };
            "else" = "false";
          };
        };
      }

      # ---- Spam allowlist: daniel's own Gmail forward ----
      # daniel's personal Gmail (wraithx2@gmail.com) forwards to
      # daniel@lyte.dev. Gmail's forwarder rewrites the SMTP envelope sender
      # with SRS (e.g. wraithx2+caf_=daniel=lyte.dev@gmail.com), and the
      # forward strips daniel@lyte.dev from the visible To/Cc headers. That
      # combination trips Stalwart's forwarding-artifact heuristics
      # (FORGED_RECIPIENTS +2.0, FORGED_RCVD_TRAIL +1.0, FORGED_SENDER +0.3,
      # FAKE_REPLY +1.0, …), pushing otherwise-legitimate forwarded mail over
      # the junk threshold even though it authenticates cleanly
      # (spf=pass / dkim=pass from Google's IPs).
      #
      # These are false positives caused purely by the forward, so we grant
      # the built-in TRUSTED_DOMAIN tag (score -7) to mail whose *envelope*
      # sender is daniel's Gmail SRS forward, gated on SPF pass so a spoofer
      # can't forge the envelope address (Google's IPs are the only ones that
      # pass SPF for gmail.com). We deliberately match the envelope (env_from),
      # not the From: header, because the From: still shows the original
      # third-party sender — it's the SRS envelope that uniquely identifies
      # daniel's own forwarder.
      #
      # Scoped destroy-by-name (NOT destroy-all): a filter value matches
      # only that rule, leaving stalwart's ~66 built-in SpamRules intact
      # (verified: a destroy with a non-matching name reports "0 destroyed").
      {
        "@type" = "destroy";
        object = "SpamRule";
        value.name = "DANIEL_GMAIL_FORWARD";
      }
      {
        "@type" = "create";
        object = "SpamRule";
        value.daniel-gmail-forward = {
          "@type" = "Any";
          name = "DANIEL_GMAIL_FORWARD";
          description = "daniel's own Gmail forward (SRS envelope) is trusted (requires SPF pass)";
          enable = true;
          priority = 100;
          condition = {
            match."0" = {
              # env_from is the full SMTP MAIL FROM address; Gmail's forward
              # SRS form embeds "+caf_=daniel=lyte.dev" in the local part and
              # always lives under @gmail.com. Gate on SPF pass so the
              # envelope can't be spoofed.
              "if" =
                "$SPF_ALLOW && env_from.domain == 'gmail.com' && contains(env_from, '+caf_=daniel=lyte.dev')";
              "then" = "'TRUSTED_DOMAIN'";
            };
            "else" = "false";
          };
        };
      }

      # ---- OAuth client for Bulwark webmail ----
      # Replaces the old curl-based stalwart-ensure-bulwark-oauth.service.
      # NOTE: bulwark now authenticates against Kanidm (see the Oidc
      # Directory below); this internal OAuth client is kept for now as a
      # fallback until the Kanidm path is verified, then can be removed.
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
          # Bulwark 1.7.x sends its locale-prefixed page route as the
          # redirect_uri (e.g. /en/auth/callback). Stalwart's authorize step
          # is lenient but the token exchange strictly matches against this
          # set — a missing entry fails the exchange with access_denied.
          redirectUris = {
            "https://webmail.${domain}/api/auth/callback" = true;
            "https://webmail.${domain}/en/auth/callback" = true;
            "https://webmail.${domain}/auth/callback" = true;
          };
        };
      }

      # ---- OIDC directory: validate Kanidm-issued tokens ----
      # Additive: the internal directory (accounts + passwords for IMAP/SMTP
      # AUTH PLAIN) is untouched. This directory lets stalwart accept bearer
      # tokens / XOAUTH2 minted by Kanidm for the bulwark-webmail client.
      # Stalwart validates JWTs locally against the issuer's JWKS (userinfo
      # is only called for opaque tokens / missing claims) and maps
      # preferred_username (+ usernameDomain when the claim lacks an @) onto
      # existing accounts via name-in-domain lookup:
      # "daniel" → daniel@lyte.dev → existing internal account "daniel"
      # (same account id and mailbox; JIT-creates only when nothing matches).
      #
      # Setting directoryId routes Basic (password) auth exclusively to the
      # OIDC directory — breaking IMAP/SMTP AUTH PLAIN. This is INTENTIONAL:
      # we are retiring password clients entirely (bulwark PWA everywhere).
      # Sandbox-verified 2026-06-10: STALWART_RECOVERY_ADMIN basic auth
      # still works with directoryId set, so stalwart-apply survives.
      # The directory itself is managed by the module (oidcDirectory option)
      # so its runtime id is stable and substitutable here.
      {
        "@type" = "update";
        object = "Authentication";
        value.directoryId = "@OIDC_DIRECTORY_ID@";
      }
    ];

    # The Oidc directory is ensured by the apply script (create-or-update by
    # description match) rather than destroy+create in the plan — the
    # Authentication singleton must reference its id, which has to stay
    # stable across applies. Exposes @OIDC_DIRECTORY_ID@ to the plan.
    oidcDirectory = {
      "@type" = "Oidc";
      description = "Kanidm OIDC (bulwark webmail SSO)";
      issuerUrl = "https://idm.h.lyte.dev/oauth2/openid/bulwark-webmail";
      claimUsername = "preferred_username";
      claimName = "name";
      usernameDomain = domain;
      # Reject tokens minted for other Kanidm clients.
      requireAudience = "bulwark-webmail";
    };
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

  # Fallback SMTP listener (2526) is reachable only over the tailnet, never
  # the public internet — it's the plain-SMTP target for pebble's outage
  # queue (which can't speak PROXY protocol).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2526 ];

  # CORS: stalwart 0.16 emits its own Access-Control-* headers on normal
  # responses but NOT on its 307 redirects (e.g. /.well-known/jmap), and
  # browsers block those for cross-origin callers like bulwark. The `?`
  # header modifier sets a default only when the field is absent, so we
  # never duplicate Access-Control-Allow-Origin (duplicates are rejected
  # by browsers outright — that broke OIDC discovery before).
  services.caddy.virtualHosts.${host} = {
    extraConfig = ''
      header ?Access-Control-Allow-Origin "*"
      header ?Access-Control-Allow-Headers "Authorization, Content-Type, Accept, X-Requested-With"
      header ?Access-Control-Allow-Methods "POST, GET, PATCH, PUT, DELETE, HEAD, OPTIONS"

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
