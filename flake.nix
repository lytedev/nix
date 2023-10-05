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

    color-schemes = let
      mkColorScheme = scheme @ {
        scheme-name,
        bg,
        bg2,
        bg3,
        bg4,
        bg5,
        fg,
        fg2,
        fg3,
        fgdim,
        # pink,
        purple,
        red,
        orange,
        yellow,
        green,
        # teal,
        blue,
      }: let
        base =
          {
            # aliases?
            text = fg;
            primary = blue;
            urgent = red;

            # blacks
            "0" = bg4;
            "8" = bg5;

            "1" = red;
            "9" = red;
            "2" = green;
            "10" = green;
            "3" = orange;
            "11" = orange;
            "4" = blue;
            "12" = blue;
            "5" = purple;
            "13" = purple;
            "6" = yellow;
            "14" = yellow;

            # whites
            "7" = fg2;
            "15" = fg3;
          }
          // scheme;
      in
        {
          withHashPrefix = inputs.nixpkgs-unstable.lib.mapAttrs (_: value: "#${value}") base;
        }
        // base;
    in {
      donokai = mkColorScheme {
        scheme-name = "donokai";
        bg = "111111";
        bg2 = "181818";
        bg3 = "222222";
        bg4 = "292929";
        bg5 = "333333";

        fg = "f8f8f8";
        fg2 = "d8d8d8";
        fg3 = "c8c8c8";
        fgdim = "666666";

        red = "f92672";
        green = "a6e22e";
        yellow = "f4bf75";
        blue = "66d9ef";
        purple = "ae81ff";
        # teal = "a1efe4";
        orange = "fab387";
      };
      catppuccin-mocha-sapphire = mkColorScheme {
        scheme-name = "catppuccin-mocha-sapphire";
        bg = "1e1e2e";
        bg2 = "181825";
        bg3 = "313244";
        bg4 = "45475a";
        bg5 = "585b70";

        fg = "cdd6f4";
        fg2 = "bac2de";
        fg3 = "a6adc8";
        fgdim = "6c7086";

        # pink = "f5e0dc";
        purple = "cba6f7";
        red = "f38ba8";
        orange = "fab387";
        yellow = "f9e2af";
        green = "a6e3a1";
        # teal = "94e2d5";
        blue = "74c7ec";
      };
    };

    colors = color-schemes.catppuccin-mocha-sapphire;
    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };

    linuxHomeManagerModules = [./home ./home/linux.nix];

    forAllSystems = nixpkgs-stable.lib.genAttrs systems;
  in {
    # TODO: nix-color integration?
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
      mkNixosSystem = cb: system: modules:
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
                    imports = linuxHomeManagerModules;
                  };
                };
              }
            ];
        };
      # mkNixosStableSystem = mkNixosSystem nixpkgs-stable.lib.nixosSystem;
      mkNixosUnstableSystem = mkNixosSystem nixpkgs-unstable.lib.nixosSystem;
    in {
      dragon = mkNixosUnstableSystem "x86_64-linux" [./nixos/dragon];
      thinker = mkNixosUnstableSystem "x86_64-linux" [./nixos/thinker];
      beefcake = mkNixosUnstableSystem "x86_64-linux" [
        inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
        ./nixos/beefcake
      ];
      rascal = mkNixosUnstableSystem "x86_64-linux" [./nixos/rascal];
      musicbox = mkNixosUnstableSystem "x86_64-linux" [./nixos/musicbox];
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = let
      mkHome = system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs-unstable.legacyPackages.${system};
          extraSpecialArgs = {inherit inputs outputs system colors font;};
          modules = modules;
        };
    in {
      "daniel" = mkHome "x86_64-linux" linuxHomeManagerModules;
      "daniel.flanagan" = mkHome "aarch64-darwin" [./home];
    };

    # TODO: darwin for work?
    # TODO: nixos ISO?

    # Disk partition schemes and functions
    diskoConfigurations = import ./disko;
  };
}
