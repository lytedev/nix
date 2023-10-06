{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    helix.url = "github:helix-editor/helix/75c0a5ceb32d8a503915a93ccc1b64c8ad1cba8b";
    disko.url = "github:nix-community/disko/master";
    sops-nix.url = "github:Mic92/sops-nix";
    hardware.url = "github:nixos/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland";

    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";

    # TODO: ssbm.url = "github:djanatyn/ssbm-nix";

    # need to bump ishiiruka upstream I think
    # slippi-desktop.url = "github:project-slippi/slippi-desktop-app";
    # slippi-desktop.flake = false;
    # ssbm.inputs.slippi-desktop.follows = "slippi-desktop";
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

    color-schemes = (import ./lib/colors.nix inputs).schemes;
    colors = color-schemes.catppuccin-mocha-sapphire;
    # colors = (import ./lib/colors.nix inputs).color-schemes.donokai;
    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };
  in {
    # TODO: nix-color integration?
    # Your custom packages
    # Acessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs-unstable.legacyPackages.${system});

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
      mkNixosSystem = cb: system: modules: homeManagerModules:
        cb {
          system = system;
          specialArgs = {
            inherit inputs outputs system colors font;
            flake = self;
          };
          modules =
            [
              inputs.sops-nix.nixosModules.sops
              self.nixosModules.common
            ]
            ++ modules
            ++ [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  extraSpecialArgs = {inherit inputs outputs system colors font;};
                  users.daniel = {
                    imports = homeManagerModules;
                  };
                };
              }
            ];
        };
      # mkNixosStableSystem = mkNixosSystem nixpkgs-stable.lib.nixosSystem;
      mkNixosUnstableSystem = mkNixosSystem nixpkgs-unstable.lib.nixosSystem;
    in {
      dragon = mkNixosUnstableSystem "x86_64-linux" [./nixos/dragon] (with outputs.homeManagerModules; [
        dragon
      ]);
      thinker = mkNixosUnstableSystem "x86_64-linux" [./nixos/thinker] (with outputs.homeManagerModules; [
        thinker
      ]);
      beefcake =
        mkNixosUnstableSystem "x86_64-linux" [
          inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
          ./nixos/beefcake
        ] (with outputs.homeManagerModules; [
          linux
        ]);
      rascal = mkNixosUnstableSystem "x86_64-linux" [./nixos/rascal] (with outputs.homeManagerModules; [
        linux
      ]);
      musicbox = mkNixosUnstableSystem "x86_64-linux" [./nixos/musicbox] (with outputs.homeManagerModules; [
        sway
      ]);
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      # TODO: non-system-specific home configurations?
      "base-x86_64-linux" = home-manager.lib.homeManagerConfiguration rec {
        system = "x86_64-linux";
        pkgs = nixpkgs-unstable.legacyPackages.${system};
        extraSpecialArgs = {inherit inputs outputs system colors font;};
        modules = with outputs.homeManagerModules; [linux];
      };
      "base-aarch64-darwin" = home-manager.lib.homeManagerConfiguration rec {
        system = "aarch64-darwin";
        pkgs = nixpkgs-unstable.legacyPackages.${system};
        extraSpecialArgs = {inherit inputs outputs system colors font;};
        modules = with outputs.homeManagerModules; [macos];
      };
    };

    # TODO: nix-on-droid for phone terminal usage?
    # TODO: nix-darwin for work?
    # TODO: nixos ISO?

    # Disk partition schemes and functions
    diskoConfigurations = import ./disko;
  };
}
