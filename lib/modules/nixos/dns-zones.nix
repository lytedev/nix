{ dns-nix, ... }:
{
  lib,
  config,
  ...
}:
let
  dnsLib = dns-nix.lib;
  inherit (lib) mkOption types;

  # DKIM public key (RSA, from stalwart._domainkey.lyte.dev)
  dkimPubKey = builtins.concatStringsSep "" [
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyAoaMRRXTV/5vYJanS08"
    "r0ELsDLqqABSiXoAwHE1fILyxFNBs6bwIMXVhu4q3H/EElF0sXh+lroW7OBSn8vV"
    "N7YZzjIF4otweoFgF02upOCDFX03Rk+yipLykEq7hWeLzvneM2MMaWnOScUl5KDb"
    "d6+Wzww3NXDLDDUhhzjjD5yxnPPkKHI9F0A3aj/jxO8s4XA7iBfZKMCw+qFFRJka"
    "e1VsoNn6pMe7p13vGXVHdfRI5/YAvLZnQeoZaQsl7pdemT8qnjhOmSbZ6QgER+18"
    "Fv2IhR88GhfIGGRS4sXw0eF3+HUSjWSoIsZb5AyA+vU3/mVRneqUepIzIxReDIEX"
    "tQIDAQAB"
  ];

  # --- lyte.dev zone ---
  lyteDev = {
    SOA = {
      nameServer = "ns0.1984.is.";
      adminEmail = "dns@lyte.dev";
      serial = 2025032500;
      refresh = 7200;
      retry = 3600;
      expire = 1209600;
      minimum = 3600;
    };

    NS = [
      "ns0.1984.is."
      "ns1.1984.is."
      "ns2.1984.is."
      "ns1.he.net."
      "ns2.he.net."
      "ns3.he.net."
      "ns4.he.net."
      "ns5.he.net."
    ];

    # Root A record — pebble's static IP
    A = [ "204.168.181.230" ];

    # Mail
    MX = [
      {
        preference = 10;
        exchange = "pebble.lyte.dev.";
      }
    ];

    TXT = [
      # SPF
      "v=spf1 include:mailgun.org a:pebble.lyte.dev ~all"
    ];

    subdomains = {
      # DMARC policy
      _dmarc.TXT = [ "v=DMARC1; p=quarantine; rua=mailto:postmaster@lyte.dev" ];

      # DKIM
      "stalwart._domainkey".TXT = [ dkimPubKey ];

      # Mailgun sending verification
      email.CNAME = [ "mailgun.org." ];

      # --- Static records ---
      pebble.A = [ "204.168.181.230" ];

      # --- Dynamic records (initial values, updated by dns-updater) ---
      # beefcake subdomains — these will be overwritten by nsupdate
      "beefcake.h".A = [ "0.0.0.0" ];
      "paperless.h".A = [ "0.0.0.0" ];
      git.A = [ "0.0.0.0" ];
      "grafana.h".A = [ "0.0.0.0" ];
      "prometheus.h".A = [ "0.0.0.0" ];
      "finances.h".A = [ "0.0.0.0" ];
      video.A = [ "0.0.0.0" ];
      "video.h".A = [ "0.0.0.0" ];
      audio.A = [ "0.0.0.0" ];
      "audio.h".A = [ "0.0.0.0" ];
      "tasks.h".A = [ "0.0.0.0" ];
      "spacetimedb.h".A = [ "0.0.0.0" ];
      "idm.h".A = [ "0.0.0.0" ];
      "*.vpn.h".A = [ "0.0.0.0" ];
      "vpn4.h".A = [ "0.0.0.0" ];
      "vpn.h".A = [ "0.0.0.0" ];
      "nix.h".A = [ "0.0.0.0" ];
      "nextcloud.h".A = [ "0.0.0.0" ];
      "onlyoffice.h".A = [ "0.0.0.0" ];
      "atuin.h".A = [ "0.0.0.0" ];
      mail.A = [ "0.0.0.0" ];
      files.A = [ "0.0.0.0" ];
      a.A = [ "0.0.0.0" ];
      api.A = [ "0.0.0.0" ];
      matrix.A = [ "0.0.0.0" ];
      "hookshot.matrix".A = [ "0.0.0.0" ];
      element.A = [ "0.0.0.0" ];
      bw.A = [ "0.0.0.0" ];
      webmail.A = [ "0.0.0.0" ];

      # router subdomains
      "router.h".A = [ "0.0.0.0" ];
      h.A = [ "0.0.0.0" ];
      "*.h".A = [ "0.0.0.0" ];

      # other dynamic hosts
      "dragon.h".A = [ "0.0.0.0" ];
      "ruby.remote".A = [ "0.0.0.0" ];
      "rift.remote".A = [ "0.0.0.0" ];
      ourcraft.A = [ "0.0.0.0" ];
      "bouncyballs.m".A = [ "0.0.0.0" ];
      "chromebox.h".A = [ "0.0.0.0" ];
    };
  };

  # --- dmf.me zone ---
  dmfMe = {
    SOA = {
      nameServer = "ns0.1984.is.";
      adminEmail = "dns@lyte.dev";
      serial = 2025032500;
      refresh = 7200;
      retry = 3600;
      expire = 1209600;
      minimum = 3600;
    };

    NS = [
      "ns0.1984.is."
      "ns1.1984.is."
      "ns2.1984.is."
      "ns1.he.net."
      "ns2.he.net."
      "ns3.he.net."
      "ns4.he.net."
      "ns5.he.net."
    ];

    # Router manages @ and * for dmf.me
    A = [ "0.0.0.0" ];
    subdomains = {
      "*".A = [ "0.0.0.0" ];
    };
  };
in
{
  options.lyte.dns = {
    zones = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "Generated zone file strings keyed by zone name.";
    };
  };

  config.lyte.dns.zones = {
    "lyte.dev" = dnsLib.toString "lyte.dev" lyteDev;
    "dmf.me" = dnsLib.toString "dmf.me" dmfMe;
  };
}
