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
    # Default record cache duration ($TTL). Short (5m) so changes — especially to
    # the dynamic home WAN IP records — propagate to resolvers quickly instead of
    # lingering for a day. (dns.nix default is 24h.)
    TTL = 300;

    SOA = {
      nameServer = "ns0.1984.is.";
      adminEmail = "dns@lyte.dev";
      # NOTE (temporary, 2026-06): while pebble (the normal hidden-primary) is
      # offline, beefcake serves this zone as a temporary hidden primary. Serial
      # must exceed the live serial the secondaries are frozen on (2025032567)
      # or they will reject beefcake's zone as older. Bumped well past it.
      serial = 2026062400;
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
      # TEMPORARY (2026-06): pebble is offline (Hetzner billing lock). The MX
      # (-> pebble.lyte.dev) and SPF (a:pebble.lyte.dev) both key off this A
      # record, so pointing it at the home WAN IP routes inbound mail to
      # beefcake directly with NO dependency on the dynamic `mail` record being
      # populated yet. REVERT to 204.168.181.230 once pebble is back online.
      pebble.A = [ "136.33.254.144" ];

      "login.alaeria".CNAME = [ "alias.deno.net." ];
      "_acme-challenge.login.alaeria".CNAME = [ "_acme.deno.net." ];

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
