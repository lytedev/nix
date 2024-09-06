{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  inherit (lib.strings) optionalString;
  cfg = config.services.deno-netlify-ddns-client;
in {
  options.services.deno-netlify-ddns-client = {
    enable = mkEnableOption "Enable the deno-netlify-ddns client.";
    username = mkOption {
      type = types.str;
    };
    passwordFile = mkOption {
      type = types.str;
    };
    endpoint = mkOption {
      type = types.str;
      default = "https://netlify-ddns.deno.dev";
    };
    ipv4 = mkOption {
      type = types.bool;
      default = true;
    };
    ipv6 = mkOption {
      type = types.bool;
      default = true;
    };
    requestTimeout = mkOption {
      type = types.int;
      description = "The maximum number of seconds before the HTTP request times out.";
      default = 30;
    };
    afterBootTime = mkOption {
      type = types.str;
      description = "A systemd.timers timespan. This option corresponds to the OnBootSec field in the timerConfig.";
      default = "5m";
    };
    every = mkOption {
      type = types.str;
      description = "A systemd.timers timespan. This option corresponds to the OnUnitActiveSec field in the timerConfig.";
      default = "5m";
    };
  };

  config = {
    systemd.timers.deno-netlify-ddns-client = {
      enable = mkIf cfg.enable true;
      after = ["network.target"];
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = cfg.afterBootTime;
        OnUnitActiveSec = cfg.every;
        Unit = "deno-netlify-ddns-client.service";
      };
    };

    systemd.services.deno-netlify-ddns-client = {
      enable = mkIf cfg.enable true;
      after = ["network.target"];
      script = ''
        set -eu
        password="$(cat "${cfg.passwordFile}")"
        ${optionalString cfg.ipv4 ''
          ${pkgs.curl}/bin/curl -4 -s \
            -X POST \
            --max-time ${toString cfg.requestTimeout} \
            -u "${cfg.username}:''${password}" \
            -L "${cfg.endpoint}/v1/netlify-ddns/replace-all-relevant-user-dns-records"
        ''}
        ${optionalString cfg.ipv6 ''
          ${pkgs.curl}/bin/curl -6 -s \
            -X POST \
            --max-time ${toString cfg.requestTimeout} \
            -u "${cfg.username}:''${password}" \
            -L "${cfg.endpoint}/v1/netlify-ddns/replace-all-relevant-user-dns-records"
        ''}
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };
}