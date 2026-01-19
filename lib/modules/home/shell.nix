{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    lyte = {
      useOutOfStoreSymlinks = {
        enable = lib.mkEnableOption "Enable the use of mkOutOfStoreSymlink for certain configuration files for faster editing, but means /etc/nixos and /etc/nix/flake must point to this flake in order to work";
      };
      shell = {
        enable = lib.mkEnableOption "Enable home-manager shell configuration for the user";
        learn-jujutsu-not-git = {
          enable = lib.mkEnableOption "Soft-disable the 'git' command in an effort to force me to learn jujutsu (jj)";
        };
      };
    };
  };

  config = lib.mkIf config.lyte.shell.enable {
    programs.fish.enable = true;
    programs.helix.enable = true;
    programs.zellij.enable = lib.mkDefault true;
    programs.eza.enable = true;
    programs.bat = {
      enable = true;
      config = {
        theme = "ansi";
      };
      /*
        themes = {
          "Catppuccin-mocha" = builtins.readFile (pkgs.fetchFromGitHub
            {
              owner = "catppuccin";
              repo = "bat";
              rev = "477622171ec0529505b0ca3cada68fc9433648c6";
              sha256 = "6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
            }
            + "/Catppuccin-mocha.tmTheme");
        };
      */
    };

    home.shellAliases = {
      cat = "bat";
    };

    programs.home-manager.enable = true;

    programs.direnv.mise = {
      enable = true;
    };

    programs.mise = {
      enable = lib.mkDefault false;
      enableFishIntegration = config.programs.mise.enable && config.programs.fish.enable;
      enableBashIntegration = config.programs.mise.enable && config.programs.bash.enable;
      enableZshIntegration = config.programs.mise.enable && config.programs.zsh.enable;
    };

    programs.jujutsu = {
      enable = true;
    };

    programs.jq = {
      enable = true;
    };

    programs.btop = {
      enable = true;
      package = pkgs.btop.override {
        rocmSupport = true;
      };
    };

    # services.ssh-agent.enable = true;

    home = {
      sessionVariables = {
        TERMINAL = "ghostty";
        EDITOR = "hx";
        VISUAL = "hx";
        PAGER = "less";
        MANPAGER = "less";
      };

      packages = with pkgs; [
        bitwarden-cli
        nixfmt-rfc-style
        nixd
        nil
        (pkgs.buildEnv {
          name = "my-common-scripts";
          paths = [ ./scripts/common ];
        })
      ];
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.skim = {
      # https://github.com/lotabout/skim/issues/494
      enable = false;
      enableFishIntegration = true;
      defaultOptions = [
        "--no-clear-start"
        "--color=16"
        "--height=20"
      ];
    };

    programs.atuin = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableNushellIntegration = config.programs.nushell.enable;

      flags = [
        "--disable-up-arrow"
      ];

      settings = {
        auto_sync = true;
        sync_frequency = "1m";
        sync_address = "https://atuin.h.lyte.dev";
        keymap_mode = "vim-insert";
        inline_height = 20;
        show_preview = true;

        sync = {
          records = true;
        };

        dotfiles = {
          enabled = true;
        };
      };
    };

    programs.fzf = {
      # using good ol' fzf until skim sucks less out of the box I guess
      enable = true;
      /*
        enableFishIntegration = true;
        defaultCommand = "fd --type f";
        defaultOptions = ["--height 40%"];
        fileWidgetOptions = ["--preview 'head {}'"];
      */
    };

    # TODO: regular cron or something?
    programs.nix-index = {
      enable = true;

      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
    };
  };
}
