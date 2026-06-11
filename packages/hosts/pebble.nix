{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Beefcake's Stalwart instance over Tailscale VPN
  beefcakeSmtp = "beefcake.internal.vpn.h.lyte.dev";
  domain = "lyte.dev";
in
{
  # This is a small (2-core) box. Without the lyte/upstream binary caches its
  # nix-daemon falls back to building overlay/custom packages from source, which
  # is painfully slow. Mirror the flake's nixConfig substituters so it can pull
  # prebuilt closures (esp. from nix.h.lyte.dev) instead of compiling. Deploys
  # also build off-box (remoteBuild = false in lib/deploy) for the same reason.
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nix.h.lyte.dev"
      "https://iosevka-lyte.cachix.org"
      "https://helix.cachix.org"
      "https://ghostty.cachix.org"
      "https://jovian-nixos.cachix.org"
      "https://install.determinate.systems"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M="
      "iosevka-lyte.cachix.org-1:5pX+LwVdlfWJtmubPErASJecnm1q3a/RoZmah1GU+FM="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "jovian-nixos.cachix.org-1:mAWLjAxLNlfxAnozUjOqGj4AxQwCl7MXwOfu7msVlAo="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  sops = {
    defaultSopsFile = ../../secrets/pebble/secrets.yml;
    secrets = {
      netlify-ddns-password.mode = "0400";
      tsig-beefcake-h.mode = "0440";
      tsig-beefcake-h.group = "knot";
      tsig-router-h.mode = "0440";
      tsig-router-h.group = "knot";
      tsig-pebble.mode = "0440";
      tsig-pebble.group = "knot";
      tsig-secondary-1984.mode = "0440";
      tsig-secondary-1984.group = "knot";
      tsig-secondary-he.mode = "0440";
      tsig-secondary-he.group = "knot";
    };
  };

  # Keep existing DDNS client during parallel-run phase
  services.deno-netlify-ddns-client = {
    enable = true;
    passwordFile = config.sops.secrets.netlify-ddns-password.path;
    username = "pebble";
  };

  # DKIM public key — single source of truth, referenced by dns-zones for the TXT record
  # Corresponding private key: sops secrets/beefcake/secrets.yml stalwart-dkim-private-key
  lyte.dns.dkimPublicKey = builtins.concatStringsSep "" [
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyAoaMRRXTV/5vYJanS08"
    "r0ELsDLqqABSiXoAwHE1fILyxFNBs6bwIMXVhu4q3H/EElF0sXh+lroW7OBSn8vV"
    "N7YZzjIF4otweoFgF02upOCDFX03Rk+yipLykEq7hWeLzvneM2MMaWnOScUl5KDb"
    "d6+Wzww3NXDLDDUhhzjjD5yxnPPkKHI9F0A3aj/jxO8s4XA7iBfZKMCw+qFFRJka"
    "e1VsoNn6pMe7p13vGXVHdfRI5/YAvLZnQeoZaQsl7pdemT8qnjhOmSbZ6QgER+18"
    "Fv2IhR88GhfIGGRS4sXw0eF3+HUSjWSoIsZb5AyA+vU3/mVRneqUepIzIxReDIEX"
    "tQIDAQAB"
  ];

  # --- Knot DNS authoritative server ---
  lyte.dns-server = {
    enable = true;

    tsigKeys = {
      beefcake-h = {
        secretFile = config.sops.secrets.tsig-beefcake-h.path;
      };
      router-h = {
        secretFile = config.sops.secrets.tsig-router-h.path;
      };
      pebble = {
        secretFile = config.sops.secrets.tsig-pebble.path;
      };
      secondary-1984 = {
        secretFile = config.sops.secrets.tsig-secondary-1984.path;
      };
      secondary-he = {
        secretFile = config.sops.secrets.tsig-secondary-he.path;
      };
    };

    acl = [
      {
        id = "acl-update-beefcake";
        key = "beefcake-h";
        action = [ "update" ];
      }
      {
        id = "acl-update-router";
        key = "router-h";
        action = [ "update" ];
      }
      {
        id = "acl-update-pebble";
        key = "pebble";
        action = [ "update" ];
      }
      {
        id = "acl-xfr-1984";
        address = [
          "45.76.37.222" # ns0.1984.is
          "194.58.192.36" # ns1.1984.is
          "45.32.180.186" # ns2.1984.is
          "93.95.226.52" # ns2.1984.is (secondary)
          "185.42.137.114" # ns1.1984hosting.com
          "93.95.226.53" # ns2.1984hosting.com
          "93.95.224.6" # 1984 transfer server
        ];
        action = [ "transfer" ];
      }
      {
        id = "acl-xfr-he";
        key = "secondary-he";
        action = [ "transfer" ];
      }
    ];
  };

  environment.systemPackages = [ pkgs.ghostty-terminfo ];

  system.stateVersion = "25.11";
  networking.hostName = "pebble";

  # Hetzner VPS: 2 vCPU Intel Xeon, 4GB RAM, 38G disk
  # BIOS boot (no UEFI)
  diskConfig = {
    name = "unencrypted-bios";
    params = {
      disk = "/dev/sda";
    };
  };

  # GRUB for BIOS boot — disko auto-adds /dev/sda via the EF02 partition
  boot.loader.grub.enable = true;

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  networking = {
    useDHCP = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        22
        25 # SMTP inbound
        53 # DNS
      ];
      allowedUDPPorts = [
        53 # DNS
      ];
    };
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--accept-routes"
    ];
  };

  lyte.server.enable = true;
  lyte.headscale.usePreAuthKey = true;
  lyte.shell.enable = false;

  # Disable services not needed on a minimal VPS
  services.avahi.enable = false;
  services.smartd.enable = false;

  # --- Inbound mail: HAProxy passthrough with queueing fallback ---
  #
  # HAProxy owns the public :25 and forwards raw TCP to beefcake's Stalwart
  # with PROXY protocol v2, so Stalwart sees the TRUE sender IP — full
  # SPF / DNSBL / greylisting fidelity, SMTP-time rejection to the real
  # client (no backscatter). This is the vendor-documented topology
  # (stalw.art/docs/server/reverse-proxy/haproxy/).
  #
  # When beefcake is unreachable (health check: 3 failures × 15s), HAProxy
  # fails over to a loopback-only Postfix that accepts-and-queues for up to
  # 5 days and drains to beefcake on recovery — mail is never bounced or
  # left to sender retry behavior. Fallback-path mail arrives at Stalwart
  # without PROXY headers (degraded SPF fidelity), which only affects mail
  # received during an outage window.
  services.haproxy = {
    enable = true;
    config = ''
      global
        log stdout format raw daemon notice
        maxconn 256

      defaults
        mode tcp
        log global
        option tcplog
        timeout connect 10s
        # generous: SMTP sessions are slow and chunked
        timeout client 10m
        timeout server 10m

      frontend smtp_in
        bind :25
        bind [::]:25
        default_backend stalwart

      backend stalwart
        option tcp-check
        tcp-check expect rstring ^220
        # ~45s of failures before failing over; queue absorbs the gap
        server beefcake ${beefcakeSmtp}:25 send-proxy-v2 check inter 15s fall 3 rise 2
        # loopback postfix accepts-and-queues; no PROXY support needed
        server fallback-queue 127.0.0.1:2525 backup
    '';
  };

  # --- Postfix: loopback-only fallback queue ---
  # Only receives mail when HAProxy has failed over (beefcake down).
  # Queues up to 5 days, drains to Stalwart on recovery.
  services.postfix = {
    enable = true;
    hostname = "relay.${domain}";
    domain = domain;
    origin = domain;
    destination = [ ]; # no local delivery

    relayDomains = [ domain ];

    # Transport map: route lyte.dev mail to beefcake's Stalwart over VPN.
    # Port 2526 is stalwart's plain-SMTP fallback listener — :25 there
    # requires a PROXY-protocol header from tailnet sources (HAProxy's job),
    # which postfix can't send, so the queue uses the dedicated plain port.
    transport = ''
      ${domain}    smtp:[${beefcakeSmtp}]:2526
      .${domain}   smtp:[${beefcakeSmtp}]:2526
    '';

    config = {
      # Loopback only — HAProxy is the only client (its fallback backend).
      # (The listener itself is moved to 127.0.0.1:2525 via masterConfig.)
      inet_interfaces = "127.0.0.1";
      inet_protocols = "ipv4";

      # Queue config: retry for up to 5 days if beefcake is down
      maximal_queue_lifetime = "5d";
      bounce_queue_lifetime = "5d";
      queue_run_delay = "300s";
      minimal_backoff_time = "300s";
      maximal_backoff_time = "4000s";

      # NEVER bounce on our own server's rejection. This postfix is a dumb
      # forwarder to our stalwart — it makes no real accept/reject decisions
      # about external mail (HAProxy already accepted it at the edge). If
      # stalwart returns a hard 5xx (e.g. a config error on our side), treat
      # it as temporary and keep retrying instead of generating backscatter
      # to the original sender. A genuinely bad recipient defers ≤5d then
      # bounces — acceptable for an outage-only fallback queue. (A misconfig
      # once 5xx-bounced a real message during a failover drill; this makes
      # that class of mistake recoverable, not destructive.)
      soft_bounce = "yes";

      # MX semantics: relay only for our domains, never an open relay.
      # No permit_mynetworks — even loopback clients (HAProxy-forwarded
      # external senders!) may only deliver to relay_domains.
      smtpd_relay_restrictions = [
        "reject_unauth_destination"
      ];

      # Basic SMTP hardening
      smtpd_helo_required = true;
      strict_rfc821_envelopes = true;
      disable_vrfy_command = true;

      # Announce our MX hostname
      smtpd_banner = "relay.${domain} ESMTP";

      # Don't rewrite headers
      smtp_header_checks = "";
    };
  };

  # postfix's NixOS module derives the smtp listener from master.cf; move it
  # off :25 (HAProxy owns that) onto loopback:2525.
  services.postfix.masterConfig.smtp_inet = {
    name = lib.mkForce "127.0.0.1:2525";
    type = "inet";
    private = false;
    command = "smtpd";
  };
}
