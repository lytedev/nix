{
  outputs =
    inputs:
    let
      flakeLib = import ./lib inputs;
      inherit (flakeLib) uGenPkgs;
    in
    {
      inherit flakeLib;
      packages =
        let
          base = uGenPkgs (import ./packages);
          perSystem = import ./packages/per-system.nix { inherit inputs; };
        in
        base
        // {
          x86_64-linux = (base.x86_64-linux or { }) // (perSystem.x86_64-linux or { });
          aarch64-linux = (base.aarch64-linux or { }) // (perSystem.aarch64-linux or { });
        };

      nixosConfigurations = import ./packages/hosts inputs;

      templates = import ./lib/templates;

      diskoConfigurations = import ./lib/disko inputs;
      checks = flakeLib.deployChecks // (uGenPkgs (import ./packages/checks inputs));
      devShells = uGenPkgs (import ./packages/shells inputs);

      nixosModules = import ./lib/modules/nixos inputs;

      overlays = import ./lib/overlays inputs;

      formatter = uGenPkgs (p: p.nixfmt);

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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # unstable inputs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ironbar = {
    #   url = "github:lytedev/ironbar";
    #   inputs.nixpkgs.follows = "nixpkgs-unstable";
    # };

    slippi = {
      url = "github:lytedev/slippi-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/development";
    jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # other inputs
    hardware.url = "github:NixOS/nixos-hardware";
    # nnf.url = "github:thelegy/nixos-nftables-firewall";

    helix.url = "github:helix-editor/helix/master";
    helix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";

    iosevka-lyte.url = "github:lytedev/iosevka-lyte";
    iosevka-lyte.inputs.nixpkgs.follows = "nixpkgs-unstable";

    zed = {
      url = "github:zed-industries/zed";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tuwunel = {
      # pinned to include sso_default_provider_id fix
      url = "github:matrix-construct/tuwunel/dfb65d771f4fee849a5c40c27f237cae4ec00e23";
    };

    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos";
      flake = false;
    };

    # Transitive dependencies shared by multiple inputs — pulled to root
    # level so they're deduplicated via follows instead of each input
    # vendoring its own copy in the lock file.
    #
    # NOTE: crane and rust-overlay are NOT safe to deduplicate — they are
    # tightly coupled build toolchains and version mismatches cause hash
    # resolution failures (e.g. hash '' has wrong length for 'sha1').
    flake-compat = {
      # used by: deploy-rs, ghostty, git-hooks
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils = {
      # used by: ghostty
      url = "github:numtide/flake-utils";
    };

    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    ghostty.inputs.flake-compat.follows = "flake-compat";
    git-hooks.inputs.flake-compat.follows = "flake-compat";
    ghostty.inputs.flake-utils.follows = "flake-utils";
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
      "https://iosevka-lyte.cachix.org"

      "https://helix.cachix.org"
      "https://ghostty.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M="
      "iosevka-lyte.cachix.org-1:5pX+LwVdlfWJtmubPErASJecnm1q3a/RoZmah1GU+FM="

      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
  };
}
