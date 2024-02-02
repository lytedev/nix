{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    helix.url = "github:helix-editor/helix/master";
    helix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";
    # hardware.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";
    api-lyte-dev.inputs.nixpkgs.follows = "nixpkgs";

    ssbm.url = "github:lytedev/ssbm-nix/my-nixpkgs";
    ssbm.inputs.nixpkgs.follows = "nixpkgs";

    # TODO: doesn't support the forge mod loader yet
    # nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    systems = [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    colors = (import ./lib/colors.nix inputs).schemes.catppuccin-mocha-sapphire;
    # colors = (import ./lib/colors.nix inputs).color-schemes.donokai;

    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };

    # Your custom packages
    # Acessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;

    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = builtins.mapAttrs (name: {
      system,
      modules,
      ...
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs outputs system;
          flake = self;
        };
        modules =
          [
            self.nixosModules.common
          ]
          ++ modules;
      }) (import ./nixos);

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      # TODO: non-system-specific home configurations?
      "deck" = let
        system = "x86_64-linux";
      in
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs system;
            inherit (outputs) colors font;
          };
          modules = with outputs.homeManagerModules; [
            common
            {
              home.homeDirectory = "/home/deck";
              home.username = "deck";
              home.stateVersion = "24.05";
            }
            linux
          ];
        };
    };

    # Disk partition schemes and functions
    diskoConfigurations = import ./disko;

    # Flake templates for easily setting up Nix in a project using common patterns I like
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
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
    ];
  };
}
