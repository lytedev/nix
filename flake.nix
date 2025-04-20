{
  outputs =
    inputs:
    let
      flakeLib = import ./lib inputs;
      inherit (flakeLib) uGenPkgs;
    in
    {
      inherit flakeLib;
      packages = uGenPkgs (import ./packages);

      nixosConfigurations = import ./packages/hosts inputs;
      # homeConfigurations = import ./packages/home inputs;

      templates = import ./lib/templates;

      diskoConfigurations = import ./lib/disko inputs;
      checks = flakeLib.deployChecks // (uGenPkgs (import ./packages/checks inputs));
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11?shallow=1";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # unstable inputs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable?shallow=1";

    home-manager-unstable = {
      url = "github:nix-community/home-manager?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko/master?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    slippi = {
      url = "github:lytedev/slippi-nix?shallow=1";
      # url = "git+file:///home/daniel/code/open-source/slippi-nix"; # used during flake development
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager-unstable";
    };

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/development?shallow=1";
    # jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # other inputs
    hardware.url = "github:NixOS/nixos-hardware?shallow=1";
    # nnf.url = "github:thelegy/nixos-nftables-firewall";

    # inputs with their own cache I want to use
    helix.url = "github:helix-editor/helix/master?shallow=1";
    # helix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    ghostty.url = "github:ghostty-org/ghostty?shallow=1";
    # ghostty.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    # ghostty.inputs.nixpkgs-stable.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs?shallow=1";
    # deploy-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";
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
