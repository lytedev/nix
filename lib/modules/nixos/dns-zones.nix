{ dns-nix, ... }:
{
  lib,
  config,
  ...
}:
let
  dnsLib = dns-nix.lib;
  inherit (lib) mkOption types;
  cfg = config.lyte.dns;

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

    # Root A record — Netlify load balancer
    A = [ "75.2.60.5" ];

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
      "stalwart._domainkey".TXT = [ "v=DKIM1; k=rsa; p=${cfg.dkimPublicKey}" ];

      # Mailgun sending verification
      email.CNAME = [ "mailgun.org." ];

      # --- Static records ---
      pebble.A = [ "204.168.181.230" ];

      # Dynamic A/AAAA records are NOT in the zone file. They are created
      # at runtime by the dns-updater module via nsupdate. NXDOMAIN is
      # better than routing to a bogus 0.0.0.0 if a host hasn't checked in.
    };
  };

in
{
  options.lyte.dns = {
    dkimPublicKey = mkOption {
      type = types.str;
      description = "DKIM public key (base64, no headers). Used in the stalwart._domainkey TXT record and can be referenced by other modules.";
    };

    zones = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "Generated zone file strings keyed by zone name.";
    };
  };

  config.lyte.dns.zones = {
    "lyte.dev" = dnsLib.toString "lyte.dev" lyteDev;
  };
}
