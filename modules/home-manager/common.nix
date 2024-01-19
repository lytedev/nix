{
  pkgs,
  lib,
  system,
  inputs,
  outputs,
  ...
}: {
  # TODO: fonts? right now they are only handled at the nixos-level (desktop-usage module)
  # TODO: wallpaper?

  imports = with outputs.homeManagerModules; [
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

    packages = [
      # tools I use when editing nix code
      pkgs.nil
      pkgs.alejandra

      # common scripts
      (pkgs.buildEnv {
        name = "my-scripts-common";
        paths = [./scripts/common];
      })
    ];
  };

  # TODO: not common?
  # programs.password-store = {
  #   enable = true;
  #   package = pkgs.pass.withExtensions (exts: [exts.pass-otp]);
  # };

  # programs.gitui = {
  #   enable = true;
  # };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    package = inputs.nixpkgs.legacyPackages.${system}.eza;
  };

  programs.skim = {
    # https://github.com/lotabout/skim/issues/494
    enable = false;
    enableFishIntegration = true;
    defaultOptions = ["--no-clear-start" "--color=16"];
  };

  programs.fzf = {
    # using good ol' fzf until skim sucks less out of the box I guess
    enable = true;
    enableFishIntegration = true;
    # defaultCommand = "fd --type f";
    # defaultOptions = ["--height 40%"];
    # fileWidgetOptions = ["--preview 'head {}'"];
  };

  # TODO: regular cron or something?
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  # maybe we can share somehow so things for nix-y systems and non-nix-y systems alike
  # am I going to _have_ non-nix systems anymore?
}
