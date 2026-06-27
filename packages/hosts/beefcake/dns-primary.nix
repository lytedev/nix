# beefcake = the ACTIVE hidden primary for lyte.dev (part of a redundant pair).
#
# HISTORY/WHY: lyte.dev used to have pebble (a Hetzner VPS) as its sole hidden
# primary. In 2026-06 a Hetzner billing lock killed pebble, and because it was
# the *only* box that could edit the zone, we couldn't repoint the MX — inbound
# mail died right when Daniel needed it to unlock Hetzner (a circular dependency).
# We recovered by standing knot up here and repointing the 1984 secondaries at
# beefcake. We then kept beefcake as the active primary and made pebble a
# warm-standby SECONDARY (see packages/hosts/pebble.nix) that AXFRs this zone
# over the tailnet and is also listed as a backup master at 1984. End state:
# EITHER box can die and DNS keeps serving with no manual scramble.
#
#   dns-updater (beefcake, -> 127.0.0.1)  writes dynamic records here
#   beefcake (primary, signs) ── AXFR ──> pebble (secondary)  and ──> 1984 ns0/1/2
#   1984 master list = [ beefcake, pebble ]   (falls back automatically)
#
# Why beefcake active rather than pebble: making pebble the write-primary again
# would need a fiddly knot serial re-sync (it was offline through the cutover, so
# its serial is stale/below live); beefcake-active reaches the same redundancy
# with far less risk. Trade-off — beefcake's home IP is dynamic, so if it rotates
# pebble keeps serving the last zone and a monitor alerts to repoint; pebble's
# static IP covers the converse. Inherent residual SPOF: *new* record writes need
# one active primary, but those are rare (home IP) and failover is a scripted flip.
#
# DNSSEC: lyte.dev is signed but the parent (.dev) has NO DS record, so the zone
# is insecure/unvalidated. beefcake signs with its own keys (harmless — nothing
# validates the chain); pebble, as a secondary, serves beefcake's signed copy
# verbatim (no re-signing), so the two stay byte-identical.
#
# KNOWN TEMP REMNANT (separate follow-up): dns-zones.nix `pebble.A` still points
# at the home WAN IP (a recovery hack so MX->pebble.lyte.dev routed here). Mail
# works direct to beefcake. Restoring pebble.A to 204.168.181.230 + deciding the
# MX path (pebble haproxy relay vs direct vs redundant MX) is its own change.
{ config, ... }:
let
  # The 1984.is nameservers that AXFR lyte.dev. Used both for the transfer ACL
  # and as NOTIFY targets — so they refresh within seconds of a zone change
  # instead of waiting out the 2h SOA refresh.
  nineteen84Nameservers = [
    "45.76.37.222" # ns0.1984.is
    "194.58.192.36" # ns1.1984.is
    "45.32.180.186" # ns2.1984.is
    "93.95.226.52" # ns2.1984.is (secondary)
    "185.42.137.114" # ns1.1984hosting.com
    "93.95.226.53" # ns2.1984hosting.com
    "93.95.224.6" # 1984 transfer server
  ];
  pebbleTailnet = "100.64.0.15"; # pebble (warm-standby secondary) over the tailnet
in
{
  # knot starts before tailscale assigns 100.64.0.2, so its bind to that tailnet
  # listen address would fail (and knot silently drops it — then pebble can't AXFR
  # over the tailnet). Allow binding the not-yet-present address; knot's socket
  # starts receiving once tailscale brings the IP up.
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

  # TSIG keys mirrored from pebble's sops into beefcake's (already staged). knot's
  # preStart (root) injects them into the generated config; group `knot` matches
  # pebble's convention.
  sops.secrets = {
    tsig-router-h = {
      mode = "0440";
      group = "knot";
    };
    tsig-secondary-he = {
      mode = "0440";
      group = "knot";
    };
    tsig-secondary-1984 = {
      mode = "0440";
      group = "knot";
    };
  };

  # dns-zones.nix requires this (it builds the stalwart._domainkey TXT record);
  # normally set on pebble. Same key — single DKIM keypair for the domain.
  lyte.dns.dkimPublicKey = builtins.concatStringsSep "" [
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyAoaMRRXTV/5vYJanS08"
    "r0ELsDLqqABSiXoAwHE1fILyxFNBs6bwIMXVhu4q3H/EElF0sXh+lroW7OBSn8vV"
    "N7YZzjIF4otweoFgF02upOCDFX03Rk+yipLykEq7hWeLzvneM2MMaWnOScUl5KDb"
    "d6+Wzww3NXDLDDUhhzjjD5yxnPPkKHI9F0A3aj/jxO8s4XA7iBfZKMCw+qFFRJka"
    "e1VsoNn6pMe7p13vGXVHdfRI5/YAvLZnQeoZaQsl7pdemT8qnjhOmSbZ6QgER+18"
    "Fv2IhR88GhfIGGRS4sXw0eF3+HUSjWSoIsZb5AyA+vU3/mVRneqUepIzIxReDIEX"
    "tQIDAQAB"
  ];

  # Replica of pebble's lyte.dns-server (acls + secondaries identical).
  lyte.dns-server = {
    enable = true;

    # beefcake's podman bridge runs aardvark-dns on 10.88.0.1:53, so knot cannot
    # use the 0.0.0.0 wildcard (it would collide). Bind specific addresses: the
    # loopback for the local dns-updater, the LAN IP for the public secondaries'
    # AXFR (which the router DNATs to 192.168.0.9), and the tailnet IP so pebble
    # can pull the zone over the tailnet. IPv4 only — all transfer sources are v4.
    listenAddresses = [
      "127.0.0.1@53"
      "192.168.0.9@53"
      "100.64.0.2@53" # tailnet — pebble (secondary) AXFRs from here
    ];

    tsigKeys = {
      beefcake-h.secretFile = config.sops.secrets.tsig-beefcake-h.path;
      router-h.secretFile = config.sops.secrets.tsig-router-h.path;
      secondary-1984.secretFile = config.sops.secrets.tsig-secondary-1984.path;
      secondary-he.secretFile = config.sops.secrets.tsig-secondary-he.path;
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
        id = "acl-xfr-1984";
        address = nineteen84Nameservers;
        action = [ "transfer" ];
      }
      {
        id = "acl-xfr-he";
        key = "secondary-he";
        action = [ "transfer" ];
      }
      {
        # pebble (warm-standby secondary) pulls the zone from beefcake over the
        # tailnet, so it can re-serve to 1984 if beefcake is unreachable.
        id = "acl-xfr-pebble";
        address = [ pebbleTailnet ];
        action = [ "transfer" ];
      }
    ];

    # NOTIFY every secondary on each zone change so they refresh in seconds rather
    # than waiting out the 2h SOA refresh (there is no other push — knot manages
    # the serial and we don't want to babysit propagation). Targets: the 1984
    # nameservers (reachable via the router's WAN :53 DNAT; they accept NOTIFY
    # because beefcake is one of their masters) and pebble over the tailnet (it
    # accepts NOTIFY from its master, beefcake @ 100.64.0.2). The module turns each
    # address into a knot `remote:` so `zone.notify` can reference it by name.
    secondaryNotify = nineteen84Nameservers ++ [ pebbleTailnet ];
  };
}
