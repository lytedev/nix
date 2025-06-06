{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mkIf
    ;
  cfg = config.services.spacetimedb;
in
{
  options.services.spacetimedb = {
    enable = mkEnableOption "Enable the spacetimdb server.";
    port = mkOption {
      type = types.port;
      default = 5551;
    };
    bindHost = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.settings = {
      "10-spacetimedb" = {
        "/storage/spacetimedb" = {
          "d" = {
            mode = "0700";
            user = "spacetimedb";
            group = "spacetimedb";
          };
        };
      };
    };

    users.groups.spacetimedb.members = [ "spacetimedb" ];
    users.users.spacetimedb = {
      isSystemUser = true;
      group = "spacetimedb";
    };

    systemd.services.spacetimedb = {
      serviceConfig = {
        User = "spacetimedb";
        Group = "spacetimedb";
        WorkingDirectory = "/storage/spacetimedb";
      };
      confinement = {
        packages = with pkgs; [ spacetimedb ];
      };
      enable = true;
      after = [ "network.target" ];
      script = ''${pkgs.unstable-packages.spacetimedb}/bin/spacetime --root-dir /storage/spacetimedb start --listen-addr="${cfg.bindHost}:${toString cfg.port}"'';
    };

    services.caddy = {
      virtualHosts = {
        "spacetimedb.h.lyte.dev" = {
          # this needs additional security considerations
          # https://spacetimedb.com/docs/deploying/spacetimedb-standalone#configure-nginx-reverse-proxy
          extraConfig = ''reverse_proxy :${toString cfg.port}'';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
