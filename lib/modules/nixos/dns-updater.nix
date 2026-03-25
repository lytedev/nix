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
    concatStringsSep
    concatMapStringsSep
    ;
  cfg = config.lyte.dns-updater;
in
{
  options.lyte.dns-updater = {
    enable = mkEnableOption "Dynamic DNS updater using nsupdate with TSIG keys.";

    server = mkOption {
      type = types.str;
      default = "204.168.181.230";
      description = "IP address or hostname of the Knot DNS server to send updates to.";
    };

    zone = mkOption {
      type = types.str;
      default = "lyte.dev";
      description = "DNS zone to update.";
    };

    tsigKeyFile = mkOption {
      type = types.str;
      description = "Path to a file containing the TSIG key in the format expected by nsupdate (-k flag). This should be a TSIG key file with name, algorithm, and secret.";
    };

    tsigKeyName = mkOption {
      type = types.str;
      description = "Name of the TSIG key (must match server-side configuration).";
    };

    tsigAlgorithm = mkOption {
      type = types.str;
      default = "hmac-sha256";
      description = "TSIG key algorithm.";
    };

    records = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of subdomain names to update with the host's public IP. Each entry is a subdomain (e.g., 'beefcake.h' becomes 'beefcake.h.lyte.dev').";
    };

    extraZones = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            zone = mkOption { type = types.str; };
            records = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
          };
        }
      );
      default = [ ];
      description = "Additional zones and records to update (e.g., dmf.me).";
    };

    ipv4 = mkOption {
      type = types.bool;
      default = true;
      description = "Update A records with public IPv4 address.";
    };

    ipv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Update AAAA records with public IPv6 address.";
    };

    ttl = mkOption {
      type = types.int;
      default = 60;
      description = "TTL for dynamic records.";
    };

    every = mkOption {
      type = types.str;
      default = "5m";
      description = "Systemd timer interval for updates.";
    };

    afterBootTime = mkOption {
      type = types.str;
      default = "1m";
      description = "Delay after boot before first update.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.knot-dns ];

    systemd.timers.dns-updater = {
      enable = true;
      after = [ "network-online.target" ];
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.afterBootTime;
        OnUnitActiveSec = cfg.every;
        Unit = "dns-updater.service";
      };
    };

    systemd.services.dns-updater = {
      enable = true;
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.curl
        pkgs.knot-dns
        pkgs.coreutils
      ];
      script =
        let
          # Generate nsupdate commands for a zone and its records
          mkUpdateBlock =
            zone: records: recordType: ipVar:
            let
              delAndAdd = concatMapStringsSep "\n" (
                sub:
                let
                  fqdn = if sub == "@" then "${zone}." else "${sub}.${zone}.";
                in
                ''
                  update delete ${fqdn} ${recordType}
                  update add ${fqdn} ${toString cfg.ttl} ${recordType} ''$${ipVar}''
              ) records;
            in
            ''
              zone ${zone}.
              ${delAndAdd}
              send
            '';

          # Primary zone updates
          primaryV4 = lib.optionalString (cfg.ipv4 && cfg.records != [ ]) (
            mkUpdateBlock cfg.zone cfg.records "A" "IP4"
          );
          primaryV6 = lib.optionalString (cfg.ipv6 && cfg.records != [ ]) (
            mkUpdateBlock cfg.zone cfg.records "AAAA" "IP6"
          );

          # Extra zone updates
          extraV4 = concatStringsSep "\n" (
            map (
              z: lib.optionalString (cfg.ipv4 && z.records != [ ]) (mkUpdateBlock z.zone z.records "A" "IP4")
            ) cfg.extraZones
          );
          extraV6 = concatStringsSep "\n" (
            map (
              z: lib.optionalString (cfg.ipv6 && z.records != [ ]) (mkUpdateBlock z.zone z.records "AAAA" "IP6")
            ) cfg.extraZones
          );
        in
        ''
          set -euo pipefail

          # Build TSIG key file for nsupdate
          TSIG_SECRET="$(cat "${cfg.tsigKeyFile}" | tr -d '[:space:]')"
          KEYFILE="$(mktemp /run/dns-updater-XXXXXX.key)"
          trap 'rm -f "$KEYFILE"' EXIT
          cat > "$KEYFILE" <<KEYEOF
          key "${cfg.tsigKeyName}" {
            algorithm ${cfg.tsigAlgorithm};
            secret "$TSIG_SECRET";
          };
          KEYEOF

          ${lib.optionalString cfg.ipv4 ''
            IP4="$(curl -4 -sf --max-time 10 https://api.ipify.org || curl -4 -sf --max-time 10 https://ifconfig.me)"
            if [ -z "$IP4" ]; then
              echo "ERROR: Failed to determine public IPv4 address" >&2
              exit 1
            fi
            echo "Public IPv4: $IP4"
          ''}

          ${lib.optionalString cfg.ipv6 ''
            IP6="$(curl -6 -sf --max-time 10 https://api6.ipify.org || curl -6 -sf --max-time 10 https://ifconfig.me)"
            if [ -z "$IP6" ]; then
              echo "ERROR: Failed to determine public IPv6 address" >&2
              exit 1
            fi
            echo "Public IPv6: $IP6"
          ''}

          # Send nsupdate commands
          echo "Sending DNS updates to ${cfg.server}..."
          knsupdate -k "$KEYFILE" <<UPDATEEOF
          server ${cfg.server}
          ${primaryV4}
          ${primaryV6}
          ${extraV4}
          ${extraV6}
          UPDATEEOF

          echo "DNS update complete."
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/run" ];
      };
    };
  };
}
