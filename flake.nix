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

      darwinConfigurations = import ./packages/hosts/darwin inputs;

      darwinModules = import ./lib/modules/darwin inputs;

      /*
        TODO: nix-on-droid for phone terminal usage? mobile-nixos?
        TODO: nixos ISO?
      */
    }
    // (import ./lib/constants.nix inputs);

  inputs = {
    # stable inputs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # unstable inputs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # deckmode: standalone jump-in/out gamescope gaming-mode module (foxtrot uses
    # it via packages/hosts/default.nix extraModules). Consumed as a pure module,
    # so its nixpkgs follow is only for lock dedup.
    deckmode = {
      url = "git+https://git.lyte.dev/lytedev/nixos-deckmode.git";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Transitive dependencies shared by multiple inputs — pulled to root
    # level so they're deduplicated via follows instead of each input
    # vendoring its own copy in the lock file.
    #
    # NOTE: crane and rust-overlay are NOT safe to deduplicate — they are
    # tightly coupled build toolchains and version mismatches cause hash
    # resolution failures (e.g. hash '' has wrong length for 'sha1').
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    flake-compat = {
      # used by: deploy-rs, ghostty, git-hooks
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-utils = {
      # used by: ghostty
      url = "github:numtide/flake-utils";
    };

    # modules and applications
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
    git-hooks.inputs.flake-compat.follows = "flake-compat";

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

    # Determinate Nix — lazy trees, parallel eval
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    determinate.inputs.nixpkgs.follows = "nixpkgs";

    # other inputs
    hardware.url = "github:NixOS/nixos-hardware";
    # nnf.url = "github:thelegy/nixos-nftables-firewall";

    helix.url = "github:helix-editor/helix/master";
    helix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs-unstable";
    ghostty.inputs.flake-compat.follows = "flake-compat";

    # zen-browser — Firefox fork with vertical tabs/workspaces; not in nixpkgs
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # herdr — agent-aware terminal multiplexer (default; replaced zellij)
    herdr.url = "github:ogulcancelik/herdr";
    herdr.inputs.nixpkgs.follows = "nixpkgs-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";

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

    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dns-nix = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tuwunel = {
      url = "github:matrix-construct/tuwunel";
    };

    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos";
      flake = false;
    };

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
      "https://jovian-nixos.cachix.org"
      "https://install.determinate.systems"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M="
      "iosevka-lyte.cachix.org-1:5pX+LwVdlfWJtmubPErASJecnm1q3a/RoZmah1GU+FM="

      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "jovian-nixos.cachix.org-1:mAWLjAxLNlfxAnozUjOqGj4AxQwCl7MXwOfu7msVlAo="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };
}
