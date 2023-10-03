{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";

    # TODO: avoid my manual workaround of `nix profile install helix#helix --priority 4`
    helix.url = "github:helix-editor/helix/75c0a5ceb32d8a503915a93ccc1b64c8ad1cba8b";

    disko.url = "github:nix-community/disko/master";
    sops-nix.url = "github:Mic92/sops-nix";

    # TODO: do I really need this in the root of my flake if _only_ beefcake uses it?
    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";

    hardware.url = "github:nixos/nixos-hardware";

    # TODO: hyprland.url = "github:hyprwm/Hyprland";
    # TODO: nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    self,
    nixpkgs-stable,
    nixpkgs-unstable,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    systems = [
      "aarch64-linux"
      # "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = nixpkgs-stable.lib.genAttrs systems;
  in {
    # Your custom packages
    # Acessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs-stable.legacyPackages.${system});

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs-unstable.legacyPackages.${system}.alejandra);

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
    nixosConfigurations = let
      # mkNixosSystem = system: modules:
      #   nixpkgs-stable.lib.nixosSystem {
      #     system = system;
      #     specialArgs = {
      #       inherit inputs outputs system;
      #       flake = self;
      #     };
      #     modules = [self.nixosModules.common] ++ modules;
      #   };
      mkNixosUnstableSystem = system: modules:
        nixpkgs-unstable.lib.nixosSystem {
          system = system;
          specialArgs = {
            inherit inputs outputs system;
            flake = self;
          };
          modules = [ self.nixosModules.common ] ++ modules;
        };
    in {
      dragon = mkNixosUnstableSystem "x86_64-linux" [./nixos/dragon];
      thinker = mkNixosUnstableSystem "x86_64-linux" [./nixos/thinker];
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = let
      mkHome = system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs-unstable.legacyPackages.${system};
          extraSpecialArgs = {inherit inputs outputs system;};
          modules = modules;
        };
    in {
      "daniel" = mkHome "x86_64-linux" [./home ./home/linux.nix];
      "daniel.flanagan" = mkHome "aarch64-darwin" [./home];
    };

    # TODO: darwin for work?
    # TODO: nixos ISO?

    # Disk partition schemes and functions
    diskoConfigurations = import ./disko;
  };
}
