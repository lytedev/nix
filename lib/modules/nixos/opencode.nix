{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.opencode;
  danielHome = config.users.users.daniel.home;

  opencode-wrapper = pkgs.writeShellScript "opencode-web" ''
    # Include user profile and system paths for full tool access
    export PATH="/etc/profiles/per-user/daniel/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
    export HOME="/home/daniel/.home"
    export OPENCODE_DISABLE_CHANNEL_DB=1
    export OPENCODE_EXPERIMENTAL=1
    export OPENCODE_EXPERIMENTAL_WORKSPACE=1
    exec ${cfg.package}/bin/opencode "$@"
  '';

  # Back up the canonical opencode DB before NixOS activations.
  # OPENCODE_DISABLE_CHANNEL_DB=1 ensures all channels use opencode.db directly,
  # so we no longer need symlink consolidation.
  dbBackupScript = pkgs.writeShellScript "opencode-db-backup" ''
    set -euo pipefail

    DB_DIR="${danielHome}/.local/share/opencode"
    CANONICAL="$DB_DIR/opencode.db"
    BACKUP_DIR="$DB_DIR/backups"

    mkdir -p "$BACKUP_DIR"

    if [ -f "$CANONICAL" ] && [ ! -L "$CANONICAL" ]; then
      size=$(stat -c%s "$CANONICAL" 2>/dev/null || echo 0)
      if [ "$size" -gt 0 ]; then
        ts=$(date +%Y%m%d-%H%M%S)
        backup="$BACKUP_DIR/opencode-$ts.db"
        latest=$(ls -t "$BACKUP_DIR"/opencode-*.db 2>/dev/null | head -1)
        if [ -z "$latest" ] || ! cmp -s "$CANONICAL" "$latest"; then
          cp "$CANONICAL" "$backup"
          echo "opencode-db: backed up to $backup" >&2
        fi
        # Prune old backups, keep the 10 most recent
        ls -t "$BACKUP_DIR"/opencode-*.db 2>/dev/null | tail -n +11 | xargs -r rm -f
      fi
    fi
  '';
in
{
  options.lyte.opencode = {
    enable = lib.mkEnableOption "opencode web UI daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opencode;
      defaultText = lib.literalExpression "pkgs.opencode";
      description = "The opencode package to use";
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

  config = lib.mkMerge [
    # Dotfile symlinks + DB consolidation — always present (module is imported on all hosts)
    {
      lyte.userSymlinks = {
        ".config/opencode/opencode.jsonc" = "${config.lyte.dotfilesPath}/opencode/opencode.jsonc";
        ".config/opencode/AGENTS.md" = "${config.lyte.resolvedFlakePath}/lib/modules/home/claude/CLAUDE.md";
        ".config/opencode/plugins/notify.ts" = "${config.lyte.dotfilesPath}/opencode/plugins/notify.ts";
        ".config/opencode/plugins/jj-workspace.ts" =
          "${./../../..}/dotfiles/opencode/plugins/jj-workspace.ts";
      };

      # Back up canonical DB before each activation (rebuild)
      system.userActivationScripts.opencodeDbBackup = {
        text = ''
          if [ "$(id -un)" = "daniel" ]; then
            ${dbBackupScript}
          fi
        '';
      };
    }

    # Web UI daemon — only when explicitly enabled
    (lib.mkIf cfg.enable {
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
    })
  ];
}
