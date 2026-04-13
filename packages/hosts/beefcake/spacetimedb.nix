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
    enable = mkEnableOption "Enable the spacetimedb server.";
    port = mkOption {
      type = types.port;
      default = 5551;
    };
    bindHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
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
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''${pkgs.spacetimedb}/bin/spacetime --root-dir /storage/spacetimedb start --listen-addr="${cfg.bindHost}:${toString cfg.port}"'';
    };

    services.caddy = {
      virtualHosts = {
        "spacetimedb.h.lyte.dev" = {
          # Only expose routes needed by clients; admin/publish routes require
          # SSH tunnel to localhost:${toString cfg.port} directly.
          # See: https://spacetimedb.com/docs/deploying/spacetimedb-standalone#configure-nginx-reverse-proxy
          extraConfig = ''
            # Websocket subscribe — required for all client SDKs
            @subscribe path_regexp ^/v1/database/[^/]+/subscribe$
            reverse_proxy @subscribe :${toString cfg.port}

            # Identity endpoint — required for TypeScript SDK
            @identity path /v1/identity*
            reverse_proxy @identity :${toString cfg.port}

            # Block everything else (publish, SQL, admin, etc.)
            respond 403
          '';
        };
      };
    };

    # Bound to localhost; Caddy reverse proxy handles external access.
    # Admin operations (publish, SQL, etc.) can be accessed by:
    #   - Headscale admin group devices (implicit *:* ACL access to port 5551)
    #   - SSH tunnel from non-admin devices: ssh -L 5551:127.0.0.1:5551 beefcake
  };
}
