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
      description = "IP addresses of secondary nameservers to NOTIFY.";
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
          # Build zone file entries (copy from store to Knot's zone dir)
          zoneSetup = concatStringsSep "\n" (
            mapAttrsToList (name: file: ''
              cp --no-preserve=mode "${file}" "/var/lib/knot/zones/${name}.zone"
            '') zoneFiles
          );

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

          # Zone config blocks
          zoneBlocks = concatStringsSep "\n" (
            mapAttrsToList (
              name: _file:
              let
                zoneAcls = builtins.filter (a: true) cfg.acl;
                aclIds = map (a: a.id) zoneAcls;
                aclLine = if aclIds != [ ] then "\n    acl: [${concatStringsSep ", " aclIds}]" else "";
                notifyLine =
                  if cfg.secondaryNotify != [ ] then
                    "\n    notify: [${concatStringsSep ", " cfg.secondaryNotify}]"
                  else
                    "";
              in
              "  - domain: ${name}\n    file: /var/lib/knot/zones/${name}.zone\n    storage: /var/lib/knot/zones\n    zonefile-sync: -1\n    zonefile-load: difference-no-serial\n    journal-content: all\n    semantic-checks: true\n    dnssec-signing: true\n    dnssec-policy: default-dnssec${aclLine}${notifyLine}"
            ) zoneFiles
          );

          configScript = ''
            set -euo pipefail
            mkdir -p /var/lib/knot/zones

            ${zoneSetup}

            conf="/var/lib/knot/knot.conf"

            cat > "$conf" <<'STATICEOF'
            server:
              listen: 0.0.0.0@53
              listen: ::@53

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

            # ACL section
            cat >> "$conf" <<'ACLEOF'

            acl:
            ${aclBlocks}
            ACLEOF

            # Zone section
            cat >> "$conf" <<'ZONEEOF'

            zone:
            ${zoneBlocks}
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
