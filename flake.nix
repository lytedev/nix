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

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

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
    home-manager,
    hardware,
    pre-commit-hooks,
    ...
  } @ inputs: let
    # TODO: make @ inputs unnecessary by making arguments explicit in all modules?
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: import nixpkgs {inherit system;};
    genPkgs = f: (f (forSystems pkgsFor));
  in {
    colors = (import ./lib/colors.nix {inherit (nixpkgs) lib;}).schemes.catppuccin-mocha-sapphire;
    # colors = (import ./lib/colors.nix inputs).color-schemes.donokai;

    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };

    packages = genPkgs (pkgs: import ./packages {inherit pkgs;});
    formatter = genPkgs (pkgs: pkgs.alejandra);
    checks = genPkgs (pkgs: {
      pre-commit-check = pre-commit-hooks.lib.${pkgs.system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    });

    devShell = genPkgs (pkgs:
      pkgs.mkShell {
        inherit (self.outputs.checks.${pkgs.system}.pre-commit-check) shellHook;

        buildInputs = with pkgs; [
          lua-language-server
        ];
      });

    overlays = import ./overlays {inherit nixpkgs;};
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;

    nixosConfigurations =
      (builtins.mapAttrs (name: {
          system,
          modules,
          ...
        }:
        # let
        # commonModules =
        # in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              # TODO: avoid special args and actually pass inputs to modules?
              inherit (self) outputs;
              inherit inputs hardware;
            };
            # extraSpecialArgs = {
            #   inherit inputs outputs system;
            # };
            modules =
              [
                self.nixosModules.common
              ]
              ++ modules;
          }) (import ./nixos))
      // {
        beefcake = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit (self) outputs;
            inherit inputs hardware;
          };
          modules = [self.nixosModules.common ./nixos/beefcake.nix];
        };
        # rascal = {
        #   system = "x86_64-linux";
        #   modules = [./rascal.nix];
        # };
        # router = {
        #   system = "x86_64-linux";
        #   modules = [./router.nix];
        # };
      };

    homeConfigurations = {
      # TODO: non-system-specific home configurations?
      "deck" = let
        system = "x86_64-linux";
      in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = {
            inherit (self) outputs;
            inherit inputs system;
            inherit (self.outputs) colors font;
          };
          modules = with self.outputs.homeManagerModules; [
            common
            {
              home.homeDirectory = "/home/deck";
              home.username = "deck";
              home.stateVersion = "24.05";
            }
            linux
          ];
        };
      workm1 = let
        system = "aarch64-darwin";
      in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = {
            inherit (self) outputs;
            inherit inputs system;
            inherit (self.outputs) colors font;
          };
          modules = with self.outputs.homeManagerModules; [
            common
            {
              home.homeDirectory = "/Users/daniel.flanagan";
              home.username = "daniel.flanagan";
              home.stateVersion = "24.05";
            }
            macos
          ];
        };
    };

    diskoConfigurations = import ./disko;
    templates = import ./templates/all.nix;

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
