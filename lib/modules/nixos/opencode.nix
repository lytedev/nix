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
    exec ${cfg.package}/bin/opencode "$@"
  '';

  # Consolidate all opencode DB variants into one canonical file and back up before upgrades.
  # OpenCode names the DB based on install channel (stable, local, latest, etc.) which changes
  # depending on how the binary was built. We pick one canonical file and symlink the rest.
  dbConsolidationScript = pkgs.writeShellScript "opencode-db-consolidate" ''
    set -euo pipefail

    DB_DIR="${danielHome}/.local/share/opencode"
    CANONICAL="$DB_DIR/opencode.db"
    BACKUP_DIR="$DB_DIR/backups"
    KNOWN_VARIANTS="opencode-stable opencode-local opencode-beta"

    mkdir -p "$DB_DIR" "$BACKUP_DIR"

    # Find the canonical DB: prefer existing canonical, then largest real (non-symlink) variant
    if [ ! -e "$CANONICAL" ] || [ -L "$CANONICAL" ]; then
      best=""
      best_size=0
      for variant in $KNOWN_VARIANTS; do
        f="$DB_DIR/$variant.db"
        if [ -f "$f" ] && [ ! -L "$f" ]; then
          size=$(stat -c%s "$f" 2>/dev/null || echo 0)
          if [ "$size" -gt "$best_size" ]; then
            best="$f"
            best_size="$size"
          fi
        fi
      done

      if [ -n "$best" ]; then
        echo "opencode-db: promoting $best -> $CANONICAL" >&2
        # Remove stale symlink if present
        [ -L "$CANONICAL" ] && rm -f "$CANONICAL"
        mv "$best" "$CANONICAL"
      fi
    fi

    # Back up canonical DB (if it exists and is non-empty)
    if [ -f "$CANONICAL" ] && [ ! -L "$CANONICAL" ]; then
      size=$(stat -c%s "$CANONICAL" 2>/dev/null || echo 0)
      if [ "$size" -gt 0 ]; then
        ts=$(date +%Y%m%d-%H%M%S)
        backup="$BACKUP_DIR/opencode-$ts.db"
        # Only back up if the latest backup differs (avoid duplicate backups on rapid rebuilds)
        latest=$(ls -t "$BACKUP_DIR"/opencode-*.db 2>/dev/null | head -1)
        if [ -z "$latest" ] || ! cmp -s "$CANONICAL" "$latest"; then
          cp "$CANONICAL" "$backup"
          echo "opencode-db: backed up to $backup" >&2
        fi
        # Prune old backups, keep the 10 most recent
        ls -t "$BACKUP_DIR"/opencode-*.db 2>/dev/null | tail -n +11 | xargs -r rm -f
      fi
    fi

    # Symlink all variants to canonical
    for variant in $KNOWN_VARIANTS; do
      f="$DB_DIR/$variant.db"
      if [ -f "$f" ] && [ ! -L "$f" ]; then
        # Real file that isn't the canonical — merge would need manual intervention
        echo "opencode-db: WARNING: $f is a real file with separate data, skipping symlink" >&2
        continue
      fi
      if [ -L "$f" ] && [ "$(readlink -f "$f")" = "$(readlink -f "$CANONICAL")" ]; then
        continue  # already correct
      fi
      ln -sfT "$CANONICAL" "$f"
      echo "opencode-db: symlinked $f -> $CANONICAL" >&2
    done
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
      };

      # Consolidate DB variants and back up before each activation (rebuild)
      system.userActivationScripts.opencodeDbConsolidate = {
        text = ''
          if [ "$(id -un)" = "daniel" ]; then
            ${dbConsolidationScript}
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
