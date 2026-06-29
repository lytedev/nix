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
      # beefcake is the active hidden primary that serves this zone (pebble is now
      # a secondary). knot uses difference-no-serial and manages the running serial
      # itself; this base just had to exceed the serial the secondaries were frozen
      # on during the 2026-06 cutover (2025032567), so it was bumped well past it.
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
      # pebble (a Hetzner VPS, static IP) is the lyte.dev mail front: the MX
      # (-> pebble.lyte.dev) and SPF (a:pebble.lyte.dev) both key off this A
      # record. Inbound SMTP hits pebble's HAProxy :25, which PROXY-passes through
      # to beefcake's Stalwart (:2526), with a loopback Postfix that queues for up
      # to 5 days if beefcake is unreachable (see packages/hosts/pebble.nix). Using
      # pebble's STATIC IP keeps the MX stable regardless of the dynamic home WAN
      # IP. (During the 2026-06 Hetzner lock this was temporarily 136.33.254.144 —
      # the home WAN — to route mail straight to beefcake while pebble was down.)
      pebble.A = [ "204.168.181.230" ];

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
