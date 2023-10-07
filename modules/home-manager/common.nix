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
    helix
    git
    iex
    zellij
    broot
  ];

  # TODO: specify an email?
  # accounts.email.accounts = {
  #   primary = {
  #     address = "daniel@lyte.dev";
  #   };
  # };

  home = {
    username = lib.mkDefault "daniel";
    homeDirectory = lib.mkDefault "/home/daniel/.home";
    stateVersion = lib.mkDefault "23.11";

    sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    packages = [
      # I use gawk for my fish prompt
      pkgs.gawk

      # text editor
      inputs.helix.packages.${system}.helix

      # tools I use when editing nix code
      pkgs.nil
      pkgs.alejandra

      (pkgs.buildEnv {
        name = "my-scripts-common";
        paths = [./scripts/common];
      })
    ];
  };

  programs.password-store = {
    enable = true;
    package = pkgs.pass.withExtensions (exts: [exts.pass-otp]);
  };

  programs.gitui = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${system}.eza;
  };

  programs.skim = {
    enable = true;
    enableFishIntegration = true;
    defaultOptions = ["--color=16"];
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  # maybe we can share somehow so things for nix-y systems and non-nix-y systems alike
  # am I going to _have_ non-nix systems anymore?
}
