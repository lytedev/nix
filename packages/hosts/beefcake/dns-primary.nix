# TEMPORARY (2026-06): beefcake as a hidden DNS primary for lyte.dev.
#
# WHY: pebble — the normal hidden-primary AND the mail host the MX points at —
# is offline (Hetzner account billing-locked). With pebble down we cannot edit
# the zone the 1984.is + he.net secondaries serve, so inbound mail (MX ->
# pebble.lyte.dev) is dead and Daniel can't receive the mail he needs to unlock
# Hetzner. This stands knot up on beefcake serving the same zone (from
# dns-zones.nix, whose pebble.A is temporarily pointed at the home WAN IP so the
# MX routes here), lets the existing secondaries AXFR from beefcake, and — via
# the dns-updater retarget in beefcake.nix (server -> 127.0.0.1) — repopulates
# the dynamic records on this local knot. The cutover is manual: Daniel repoints
# each secondary's master IP 204.168.181.230 -> 136.33.254.144.
#
# DNSSEC: lyte.dev is signed but the parent (.dev) has NO DS record, so the zone
# is insecure/unvalidated. beefcake's knot signs with its own freshly-generated
# keys (dns-server module default) — harmless, since nothing validates the chain.
#
# TO REVERT once pebble is restored: Daniel repoints the secondaries' master back
# to pebble; then remove this import, revert dns-zones.nix (pebble.A + serial) and
# the dns-updater `server` in beefcake.nix, and drop the :53 carve-out in
# lan-lockdown.nix and the DNS forward in router.nix.
{ config, ... }:
{
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
    # loopback for the local dns-updater, and the LAN IP for the secondaries'
    # AXFR (which the router DNATs to 192.168.0.9). IPv4 only — the secondary
    # sources are all IPv4.
    listenAddresses = [
      "127.0.0.1@53"
      "192.168.0.9@53"
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

    # secondaryNotify intentionally unset: the dns-server module would emit
    # `notify: [<ip>,...]`, but knot expects remote *names* (a `remote:` section
    # the module doesn't generate), so setting it breaks the config. pebble
    # likewise leaves it unset. After the cutover the secondaries pull on the
    # SOA refresh (2h) or an immediate manual "retransfer" from their panels.
  };
}
