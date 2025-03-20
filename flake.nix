{
  outputs =
    inputs:
    let
      flakeLib = import ./lib inputs;
      uGenPkgs = flakeLib.genPkgs inputs.nixpkgs-unstable;

      deployChecks = (
        builtins.mapAttrs (
          system: deployLib: deployLib.deployChecks inputs.self.deploy
        ) inputs.deploy-rs.lib
      );
    in
    {
      inherit flakeLib;
      packages = uGenPkgs (import ./packages);

      nixosConfigurations = import ./packages/hosts inputs;
      # homeConfigurations = import ./packages/home inputs;

      templates = import ./lib/templates;

      diskoConfigurations = import ./lib/disko inputs;
      checks = deployChecks // (uGenPkgs (import ./packages/checks inputs));
      devShells = uGenPkgs (import ./packages/shells inputs);

      nixosModules = import ./lib/modules/nixos inputs;
      homeManagerModules = import ./lib/modules/home inputs;

      overlays = import ./lib/overlays inputs;

      formatter = uGenPkgs (p: p.nixfmt-rfc-style);

      deploy = import ./lib/deploy inputs;

      /*
        TODO: nix-on-droid for phone terminal usage? mobile-nixos?
        TODO: nix-darwin for work?
        TODO: nixos ISO?
      */
    }
    // (import ./lib/constants.nix inputs);

  inputs = {
    # stable inputs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # unstable inputs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    hardware.url = "github:NixOS/nixos-hardware";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs-unstable";

    slippi.url = "github:lytedev/slippi-nix";
    # slippi.url = "git+file:///home/daniel/code/open-source/slippi-nix"; # used during flake development
    slippi.inputs.nixpkgs.follows = "nixpkgs-unstable";
    slippi.inputs.home-manager.follows = "home-manager-unstable";

    # inputs with their own cache I want to use
    helix.url = "github:helix-editor/helix/master";
    # helix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/development";
    # jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    ghostty.url = "github:ghostty-org/ghostty";
    # ghostty.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    # ghostty.inputs.nixpkgs-stable.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    # deploy-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nnf.url = "github:thelegy/nixos-nftables-firewall";
  };

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nix.h.lyte.dev"

      "https://helix.cachix.org"
      "https://ghostty.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M="

      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
  };
}
