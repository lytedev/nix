{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.claude;

  # Helper: in dev mode, create a thin wrapper that sources the script from disk
  # so edits take effect without rebuilding. In prod mode, use writeShellApplication
  # which bakes the script into the nix store and runs shellcheck at build time.
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
          (if preamble != "" then preamble + "\n" else "") + builtins.readFile (./claude + "/${name}.bash");
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
    ];
    preamble = ''
      SFX_DIR="${cfg.sfxPath}"
      SFX_VOLUME="${cfg.sfxVolume}"
      WEBHOOKS_DIR="${cfg.matrixWebhooksDir}"
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

  claude-setup = mkScript {
    name = "claude-setup";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    preamble = "HOOKS_CONFIG='${hooksConfig}'";
  };

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
      description = "Path to notification sound effects directory (files matched by glob pattern)";
    };
    sfxVolume = lib.mkOption {
      type = lib.types.str;
      default = "1.0";
      description = "Sound effect volume (0.0 - 1.0)";
    };
    matrixWebhooks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Named Matrix webhook secret file paths (name -> sops secret path) for Claude to send messages to specific rooms";
    };
    matrixWebhooksDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/state/claude/webhooks";
      description = "Directory for named webhook symlinks";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      claude-hook
      claude-notify
      claude-matrix-send
      claude-setup
    ];

    # Create symlinks from webhook secret files to a named directory
    # so claude-matrix-send can look up webhooks by name
    home.activation.claudeWebhookLinks = lib.mkIf (cfg.matrixWebhooks != { }) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${cfg.matrixWebhooksDir}"
        # Clean old links
        find "${cfg.matrixWebhooksDir}" -maxdepth 1 -type l -delete
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: path: ''
            ln -sf "${path}" "${cfg.matrixWebhooksDir}/${name}"
          '') cfg.matrixWebhooks
        )}
      ''
    );
  };
}
