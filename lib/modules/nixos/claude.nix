{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.claude;

  mkScript =
    {
      name,
      runtimeInputs,
      preamble ? "",
    }:
    if cfg.dev then
      pkgs.writeShellScriptBin name ''
        set -o errexit
        set -o nounset
        set -o pipefail
        export PATH="${lib.makeBinPath runtimeInputs}:$PATH"
        ${preamble}
        # shellcheck source=/dev/null
        source "${cfg.devScriptsPath}/${name}.bash"
      ''
    else
      pkgs.writeShellApplication {
        inherit name runtimeInputs;
        text =
          (if preamble != "" then preamble + "\n" else "")
          + builtins.readFile (../home/claude + "/${name}.bash");
      };

  hooksConfig = builtins.toJSON {
    hooks = {
      SessionStart = [
        {
          matcher = "startup|resume";
          hooks = [
            {
              type = "command";
              command = "claude-hook session-start";
            }
          ];
        }
      ];
      Notification = [
        {
          matcher = "idle_prompt";
          hooks = [
            {
              type = "command";
              command = "claude-hook notification";
            }
          ];
        }
        {
          matcher = "permission_prompt";
          hooks = [
            {
              type = "command";
              command = "claude-hook notification";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "claude-hook stop";
            }
          ];
        }
      ];
      UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = "claude-hook user-prompt";
            }
          ];
        }
      ];
      SessionEnd = [
        {
          hooks = [
            {
              type = "command";
              command = "claude-hook session-end";
            }
          ];
        }
      ];
    };
  };

  claude-hook = mkScript {
    name = "claude-hook";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
  };

  claude-notify = mkScript {
    name = "claude-notify";
    runtimeInputs = with pkgs; [
      libnotify
      pipewire
      curl
      jq
      socat
    ];
    preamble = ''
      SFX_DIR="${cfg.sfxPath}"
      SFX_VOLUME="${cfg.sfxVolume}"
      WEBHOOKS_DIR="${cfg.matrixWebhooksDir}"
      NOTIFY_PORT="${toString cfg.notifyPort}"
    '';
  };

  claude-matrix-send = mkScript {
    name = "claude-matrix-send";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    preamble = "WEBHOOKS_DIR=\"${cfg.matrixWebhooksDir}\"";
  };

  claude-notify-listen = mkScript {
    name = "claude-notify-listen";
    runtimeInputs = with pkgs; [
      socat
      jq
    ];
    preamble = ''NOTIFY_PORT="${toString cfg.notifyPort}"'';
  };

  claude-setup = mkScript {
    name = "claude-setup";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    preamble = "HOOKS_CONFIG='${hooksConfig}'";
  };

  danielHome = config.users.users.daniel.home;
in
{
  options.lyte.claude = {
    enable = lib.mkEnableOption "Claude Code hooks and notifications";
    dev = lib.mkEnableOption "dev mode: source scripts from disk instead of the nix store (edit without rebuilding)";
    devScriptsPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nix/flake/lib/modules/home/claude";
      description = "Absolute path to the claude scripts directory for dev mode";
    };
    sfxPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to notification sound effects directory";
    };
    sfxVolume = lib.mkOption {
      type = lib.types.str;
      default = "1.0";
      description = "Sound effect volume (0.0 - 1.0)";
    };
    matrixWebhooks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Named Matrix webhook secret file paths for Claude to send messages";
    };
    matrixWebhooksDir = lib.mkOption {
      type = lib.types.str;
      default = "${danielHome}/.local/state/claude/webhooks";
      description = "Directory for named webhook symlinks";
    };
    notifyPort = lib.mkOption {
      type = lib.types.int;
      default = 19199;
      description = "Port for reverse-tunnel notification forwarding";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      claude-hook
      claude-notify
      claude-notify-listen
      claude-matrix-send
      claude-setup
    ];

    lyte.userSymlinks.".claude/CLAUDE.md" =
      "${config.lyte.resolvedFlakePath}/lib/modules/home/claude/CLAUDE.md";

    # Webhook symlink creation via activation script
    system.userActivationScripts.claudeWebhookLinks = lib.mkIf (cfg.matrixWebhooks != { }) {
      text = ''
        if [ "$(id -un)" = "daniel" ]; then
          mkdir -p "${cfg.matrixWebhooksDir}"
          find "${cfg.matrixWebhooksDir}" -maxdepth 1 -type l -delete
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: path: ''
              ln -sf "${path}" "${cfg.matrixWebhooksDir}/${name}"
            '') cfg.matrixWebhooks
          )}
        fi
      '';
    };
  };
}
