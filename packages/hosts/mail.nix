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
  system.stateVersion = "25.11";
  networking.hostName = "mail";

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
    hostname = "mail.${domain}";
    domain = domain;
    origin = domain;
    destination = [ ]; # no local delivery
    networks = [ "127.0.0.0/8" "[::1]/128" ];

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
      smtpd_banner = "mail.${domain} ESMTP";

      # Don't rewrite headers
      smtp_header_checks = "";

      # Inet interfaces — listen on all for inbound
      inet_interfaces = "all";
      inet_protocols = "all";
    };
  };
}
