{
  config,
  lib,
  ...
}:
let
  # Beefcake's Stalwart instance over Tailscale VPN
  beefcakeSmtp = "beefcake.internal.vpn.h.lyte.dev";
  domain = "lyte.dev";
in
{
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
        key = "secondary-1984";
        action = [ "transfer" ];
      }
      {
        id = "acl-xfr-he";
        key = "secondary-he";
        action = [ "transfer" ];
      }
    ];
  };

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

  lyte.headscale.usePreAuthKey = true;
  lyte.shell.enable = false;
  lyte.prevent-suspend.enable = true;

  # Disable services not needed on a minimal VPS
  services.avahi.enable = false;
  services.smartd.enable = false;

  # --- Postfix: relay-only MTA ---
  # Accepts inbound mail on port 25, relays everything to beefcake's
  # Stalwart over Tailscale. No local delivery, no mailboxes.
  services.postfix = {
    enable = true;
    hostname = "relay.${domain}";
    domain = domain;
    origin = domain;
    destination = [ ]; # no local delivery
    networks = [
      "127.0.0.0/8"
      "[::1]/128"
    ];

    relayDomains = [ domain ];

    # Transport map: route lyte.dev mail to beefcake's Stalwart over VPN
    transport = ''
      ${domain}    smtp:[${beefcakeSmtp}]:25
      .${domain}   smtp:[${beefcakeSmtp}]:25
    '';

    config = {
      # Queue config: retry for up to 5 days if beefcake is down
      maximal_queue_lifetime = "5d";
      bounce_queue_lifetime = "5d";
      queue_run_delay = "300s";
      minimal_backoff_time = "300s";
      maximal_backoff_time = "4000s";

      # Security: only accept mail, don't allow open relay
      smtpd_relay_restrictions = [
        "permit_mynetworks"
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

      # Inet interfaces — listen on all for inbound
      inet_interfaces = "all";
      inet_protocols = "all";
    };
  };
}
