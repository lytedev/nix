{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.opencode;

  opencode-wrapper = pkgs.writeShellScript "opencode-web" ''
    # Include user profile and system paths for full tool access
    export PATH="/etc/profiles/per-user/daniel/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
    export HOME="/home/daniel/.home"
    exec ${pkgs.bun}/bin/bunx "opencode-ai@${cfg.version}" "$@"
  '';
in
{
  options.lyte.opencode = {
    enable = lib.mkEnableOption "opencode web UI daemon";
    version = lib.mkOption {
      type = lib.types.str;
      default = "1.2.5";
      description = "opencode npm package version to run via bun";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3966;
      description = "Port to listen on";
    };
    project = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Project directory to serve";
    };
    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths to environment files (e.g. sops secret files) to load into the service";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    systemd.services.opencode-web = {
      description = "opencode web UI";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        User = "daniel";
        Group = "daniel";
        ExecStart = "${opencode-wrapper} web --hostname 0.0.0.0 --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = cfg.environmentFiles;
      }
      // lib.optionalAttrs (cfg.project != null) {
        WorkingDirectory = cfg.project;
      };
    };
  };
}
