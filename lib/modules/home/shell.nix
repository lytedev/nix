{
  pkgs,
  lib,
  config,
  ...
}:
let
  flakePath = config.lyte.flakePath;
in
{
  options = {
    lyte = {
      flakePath = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.config/home-manager";
        description = "Absolute path to the nix flake source directory, used for out-of-store symlinks to enable live-editing of config files";
      };
      shell = {
        enable = lib.mkEnableOption "Enable home-manager shell configuration for the user";
        learn-jujutsu-not-git = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Soft-disable the 'git' command in an effort to force me to learn jujutsu (jj)";
          };
        };
      };
    };
  };

  config = lib.mkIf config.lyte.shell.enable {
    programs.fish.enable = true;
    programs.helix.enable = true;
    programs.zellij.enable = lib.mkDefault true;
    programs.eza.enable = true;
    programs.bat.enable = true;

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
        nixfmt
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
    };

    home.file."${config.xdg.configHome}/atuin/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${flakePath}/dotfiles/atuin/config.toml"
    );

    home.file."${config.xdg.configHome}/bat/config".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${flakePath}/dotfiles/bat/config"
    );

    programs.fzf = {
      # using good ol' fzf until skim sucks less out of the box I guess
      enable = true;
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
