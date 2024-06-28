{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (pkgs) system;
in {
  imports = with homeManagerModules; [
    # nix-colors.homeManagerModules.default
    fish
    bat
    helix
    git
    zellij
    broot
    nnn
    htop
    tmux
  ];

  programs.home-manager.enable = true;

  # services.ssh-agent.enable = true;

  home = {
    username = lib.mkDefault "lytedev";
    homeDirectory = lib.mkDefault "/home/lytedev";
    stateVersion = lib.mkDefault "23.11";

    sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    packages = with pkgs; [
      # tools I use when editing nix code
      nil
      alejandra
      gnupg
      (pkgs.buildEnv {
        name = "my-common-scripts";
        paths = [./scripts/common];
      })
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
  };

  programs.skim = {
    # https://github.com/lotabout/skim/issues/494
    enable = false;
    enableFishIntegration = true;
    defaultOptions = ["--no-clear-start" "--color=16"];
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
      inline_height = 10;
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
    # enableFishIntegration = true;
    # defaultCommand = "fd --type f";
    # defaultOptions = ["--height 40%"];
    # fileWidgetOptions = ["--preview 'head {}'"];
  };

  # TODO: regular cron or something?
  programs.nix-index = {
    enable = true;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableZshIntegration = config.programs.zsh.enable;
  };
}
