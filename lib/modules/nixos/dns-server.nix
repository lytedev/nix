{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    mapAttrsToList
    concatStringsSep
    filterAttrs
    ;
  cfg = config.lyte.dns-server;

  # Write zone files from dns-zones module output
  zoneFiles = lib.mapAttrs (
    name: content:
    pkgs.writeTextFile {
      name = "${name}.zone";
      text = content;
    }
  ) config.lyte.dns.zones;
in
{
  options.lyte.dns-server = {
    enable = mkEnableOption "Knot DNS authoritative server";

    tsigKeys = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            algorithm = mkOption {
              type = types.str;
              default = "hmac-sha256";
            };
            secretFile = mkOption {
              type = types.str;
              description = "Path to sops secret containing the TSIG key secret (base64).";
            };
          };
        }
      );
      default = { };
      description = "TSIG keys for dynamic updates and zone transfers.";
    };

    acl = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "ACL entries for Knot DNS.";
    };

    secondaryNotify = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "45.76.37.222"
        "100.64.0.15@53"
      ];
      description = ''
        Addresses of secondary nameservers to send NOTIFY to on every zone change,
        so they refresh immediately instead of waiting out the SOA refresh timer.
        Each entry is an IP (port 53 assumed) or `ip@port`. The module synthesizes
        a knot `remote:` per entry, since knot's `zone.notify` references remote
        names, not bare IPs. Only meaningful on a primary (applies to locally-served
        zones). Targets accept the NOTIFY because this server is one of their masters.
      '';
    };

    listenAddresses = mkOption {
      type = types.listOf types.str;
      default = [
        "0.0.0.0@53"
        "::@53"
      ];
      description = ''
        Knot `server.listen` entries. Defaults to the IPv4+IPv6 wildcards.
        Set to specific addresses (e.g. [ "127.0.0.1@53" "192.168.0.9@53" ]) on
        hosts where another service already binds an address on :53 — e.g.
        podman's aardvark-dns on its bridge gateway — since the wildcard would
        collide with that bind.
      '';
    };

    remotes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            address = mkOption {
              type = types.str;
              description = "Remote server address in knot `ip@port` form (e.g. 100.64.0.2@53).";
            };
            key = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional TSIG key id (must exist in tsigKeys) to authenticate to this remote.";
            };
          };
        }
      );
      default = { };
      description = "Knot `remote:` entries — masters this server pulls secondary zones from.";
    };

    secondaryOf = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Map of zone name -> remote id. Listed zones are served as SECONDARY
        (AXFR'd from that remote master, no local zone file, no local signing —
        the zone is served exactly as received) instead of as a local primary.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Knot DNS configuration file assembled from sops secrets at activation time.
    # We cannot use services.knot.settings directly because TSIG key secrets
    # live in sops files that are only available at runtime, not at Nix eval
    # time. Instead we generate a config template and patch in the secrets
    # via an ExecStartPre script.

    services.knot = {
      enable = true;
      package = pkgs.knot-dns;
    };

    # Build the Knot config file at service start, injecting TSIG secrets
    systemd.services.knot = {
      preStart =
        let
          # Zones we serve as a local primary = all generated zones MINUS any
          # we're configured to be a secondary for (those are AXFR'd, no file).
          primaryZoneFiles = filterAttrs (name: _: !(cfg.secondaryOf ? ${name})) zoneFiles;

          # Build zone file entries (copy from store to Knot's zone dir)
          zoneSetup = concatStringsSep "\n" (
            mapAttrsToList (name: file: ''
              cp --no-preserve=mode "${file}" "/var/lib/knot/zones/${name}.zone"
            '') primaryZoneFiles
          );

          # remote: entries (masters we pull secondary zones from)
          remoteBlocks = concatStringsSep "\n" (
            mapAttrsToList (
              id: r:
              "  - id: ${id}\n    address: ${r.address}${if r.key != null then "\n    key: ${r.key}" else ""}"
            ) cfg.remotes
          );

          # NOTIFY targets must be knot `remote:` entries — knot's zone.notify
          # references remote NAMES, not bare IPs (which is why feeding it raw IPs
          # produced an invalid config). Synthesize one remote per secondaryNotify
          # address, defaulting to port 53 when no @port is given.
          notifyRemotes = lib.imap0 (i: addr: {
            id = "notify-${toString i}";
            address = if lib.hasInfix "@" addr then addr else "${addr}@53";
          }) cfg.secondaryNotify;
          notifyRemoteBlocks = concatStringsSep "\n" (
            map (r: "  - id: ${r.id}\n    address: ${r.address}") notifyRemotes
          );
          notifyIds = map (r: r.id) notifyRemotes;

          # Combined remote section: secondary-zone masters + NOTIFY targets.
          allRemoteBlocks = concatStringsSep "\n" (
            builtins.filter (s: s != "") [
              remoteBlocks
              notifyRemoteBlocks
            ]
          );
          hasRemotes = cfg.remotes != { } || notifyRemotes != [ ];

          # Build TSIG key blocks for the config
          tsigKeyBlocks = concatStringsSep "\n" (
            mapAttrsToList (name: keyCfg: ''
              TSIG_SECRET_${
                builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name
              }="$(cat "${keyCfg.secretFile}" | tr -d '[:space:]')"
              cat >> "$conf" <<TSIGEOF
                - id: ${name}
                  algorithm: ${keyCfg.algorithm}
                  secret: $TSIG_SECRET_${builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name}
              TSIGEOF
            '') cfg.tsigKeys
          );

          # ACL config blocks
          aclBlocks = concatStringsSep "\n" (
            map (
              entry:
              let
                addressLine =
                  if entry ? address then
                    "\n    address: ${
                      if builtins.isList entry.address then builtins.head entry.address else entry.address
                    }"
                  else
                    "";
                # Handle list of addresses
                addressLines =
                  if entry ? address && builtins.isList entry.address then
                    concatStringsSep "" (map (a: "\n    address: ${a}") entry.address)
                  else
                    addressLine;
                keyLine = if entry ? key then "\n    key: ${entry.key}" else "";
                actionLine =
                  if entry ? action then
                    "\n    action: ${
                      if builtins.isList entry.action then "[${concatStringsSep ", " entry.action}]" else entry.action
                    }"
                  else
                    "";
              in
              "  - id: ${entry.id}${addressLines}${keyLine}${actionLine}"
            ) cfg.acl
          );

          # ACL ids apply to every zone this server hosts (transfer/update/notify).
          aclIdsLine =
            let
              aclIds = map (a: a.id) cfg.acl;
            in
            if aclIds != [ ] then "\n    acl: [${concatStringsSep ", " aclIds}]" else "";

          # Primary zone config blocks (served from a local, locally-signed file)
          # DNSSEC signing is OFF. The parent (.dev) publishes no DS for lyte.dev,
          # so the chain is never validated by any resolver — signing was purely
          # cosmetic (no security benefit). It also actively broke things: the HE
          # free-DNS secondaries mishandle the signed zone ("not all DNSSEC record
          # types are supported"), so records under the *.k wildcard — notably the
          # _acme-challenge TXT for the *.k.lyte.dev wildcard cert — failed to
          # appear on the HE nameservers, breaking Let's Encrypt DNS-01 validation.
          # Mail auth (SPF/DKIM/DMARC) is plain TXT and unaffected; no DANE/TLSA
          # exists. Re-enable only if .dev ever supports DS *and* HE is dropped.
          zoneBlocks = concatStringsSep "\n" (
            mapAttrsToList (
              name: _file:
              let
                notifyLine = if notifyIds != [ ] then "\n    notify: [${concatStringsSep ", " notifyIds}]" else "";
              in
              "  - domain: ${name}\n    file: /var/lib/knot/zones/${name}.zone\n    storage: /var/lib/knot/zones\n    zonefile-sync: -1\n    zonefile-load: difference-no-serial\n    journal-content: all\n    semantic-checks: true\n    dnssec-signing: false${aclIdsLine}${notifyLine}"
            ) primaryZoneFiles
          );

          # Secondary zone config blocks: AXFR'd from a master, no local file, no
          # local signing — the (already-signed) zone is served exactly as received.
          # NOTIFY from the configured master is accepted automatically by knot.
          # A secondary may also re-NOTIFY its own downstream secondaries (via
          # `secondaryNotify`) so they refresh in seconds rather than on their SOA
          # timer — e.g. pebble notifying HE's slave puller, which AXFRs from pebble.
          secondaryZoneBlocks = concatStringsSep "\n" (
            mapAttrsToList (
              name: master:
              let
                notifyLine = if notifyIds != [ ] then "\n    notify: [${concatStringsSep ", " notifyIds}]" else "";
              in
              "  - domain: ${name}\n    storage: /var/lib/knot/zones\n    master: ${master}\n    journal-content: all${aclIdsLine}${notifyLine}"
            ) cfg.secondaryOf
          );

          listenLines = concatStringsSep "\n" (map (a: "  listen: ${a}") cfg.listenAddresses);

          configScript = ''
            set -euo pipefail
            mkdir -p /var/lib/knot/zones

            ${zoneSetup}

            conf="/var/lib/knot/knot.conf"

            cat > "$conf" <<'STATICEOF'
            server:
            ${listenLines}

            log:
              - target: syslog
                any: info

            policy:
              - id: default-dnssec
                algorithm: ecdsap256sha256
                ksk-lifetime: 0
                zsk-lifetime: 30d
                nsec3: true

            STATICEOF

            # TSIG keys section
            echo "key:" >> "$conf"
            ${tsigKeyBlocks}

            # Remote (masters for secondary zones) + ACL sections
            cat >> "$conf" <<'ACLEOF'
            ${lib.optionalString hasRemotes "\nremote:\n${allRemoteBlocks}\n"}
            acl:
            ${aclBlocks}
            ACLEOF

            # Zone section (local primaries + AXFR'd secondaries)
            cat >> "$conf" <<'ZONEEOF'

            zone:
            ${zoneBlocks}
            ${secondaryZoneBlocks}
            ZONEEOF

            chown knot:knot "$conf"
            chmod 0640 "$conf"
            chown -R knot:knot /var/lib/knot/zones
          '';
        in
        lib.mkBefore configScript;

      serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.knot-dns}/bin/knotd -c /var/lib/knot/knot.conf";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
