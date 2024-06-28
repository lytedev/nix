{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    pre-commit.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    helix.url = "github:helix-editor/helix/master";
    hardware.url = "github:nixos/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland";
    slippi.url = "github:lytedev/slippi-nix";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    disko,
    # sops-nix,
    pre-commit,
    home-manager,
    helix,
    hardware,
    hyprland,
    slippi,
    ...
  }: let
    inherit (self) outputs;

    # TODO: make @ inputs unnecessary by making arguments explicit in all modules?
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {
      inherit system;
      inherit (outputs) overlays;
    });
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
    pkg = callee: overrides: genPkgs (pkgs: pkgs.callPackage callee overrides);
    vanillaPkg = callee: pkg callee {};

    # colors = (pkg ./lib/colors.nix {}).schemes.catppuccin-mocha-sapphire;

    # font = {
    #   name = "IosevkaLyteTerm";
    #   size = 12;
    # };

    moduleArgs = {
      # inherit colors font;
      inherit helix slippi hyprland hardware disko home-manager;
      inherit (outputs) nixosModules homeManagerModules diskoConfigurations overlays;
    };
  in {
    diskoConfigurations = import ./disko;
    templates = import ./templates;
    packages = vanillaPkg ./packages;

    formatter = genPkgs (p: p.alejandra);

    checks = vanillaPkg ({system}: {
      pre-commit-check = pre-commit.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    });

    devShells = vanillaPkg ({
      system,
      pkgs,
      mkShell,
    }: {
      default = mkShell {
        inherit (outputs.checks.${system}.pre-commit-check) shellHook;

        buildInputs = with pkgs; [
          lua-language-server
          nodePackages.bash-language-server
        ];
      };
    });

    overlays = {
      additions = _final: prev: outputs.packages.${prev.system};

      modifications = final: prev: {
        final.helix = helix.outputs.packages.${final.system}.helix;
      };

      unstable-packages = final: _prev: {
        final.unstable = import nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
    };

    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;

    # nixosConfigurations =
    # (builtins.mapAttrs (name: {
    #   system,
    #   modules,
    #   ...
    # }:
    #   nixpkgs.lib.nixosSystem {
    #     inherit system;
    #     # specialArgs = moduleArgs;
    #     modules =
    #       [
    #         self.nixosModules.common
    #       ]
    #       ++ modules;
    #   }) (import ./nixos))
    # // {
    #   beefcake = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs = moduleArgs;
    #     modules = [self.nixosModules.common ./nixos/beefcake.nix];
    #   };
    # };

    # homeConfigurations = {
    #   # TODO: non-system-specific home configurations?
    #   "deck" = let
    #     system = "x86_64-linux";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with self.outputs.homeManagerModules; [
    #         common
    #         {
    #           home.homeDirectory = "/home/deck";
    #           home.username = "deck";
    #           home.stateVersion = "24.05";
    #         }
    #         linux
    #       ];
    #     };
    #   workm1 = let
    #     system = "aarch64-darwin";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with self.outputs.homeManagerModules; [
    #         common
    #         {
    #           home.homeDirectory = "/Users/daniel.flanagan";
    #           home.username = "daniel.flanagan";
    #           home.stateVersion = "24.05";
    #         }
    #         macos
    #       ];
    #     };
    # };

    # TODO: nix-on-droid for phone terminal usage?
    # TODO: nix-darwin for work?
    # TODO: nixos ISO?
  };

  nixConfig = {
    extra-experimental-features = ["nix-command" "flakes"];

    extra-substituters = [
      "https://cache.nixos.org/"
      "https://helix.cachix.org"
      "https://nix-community.cachix.org"
      "https://nix.h.lyte.dev"
      "https://hyprland.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
}
