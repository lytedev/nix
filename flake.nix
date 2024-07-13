{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
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

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    disko,
    sops-nix,
    pre-commit,
    home-manager,
    helix,
    hardware,
    # hyprland,
    slippi,
    ...
  }: let
    inherit (self) outputs;
    inherit (outputs) nixosModules homeManagerModules overlays;

    # TODO: make @ inputs unnecessary by making arguments explicit in all modules?
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
    pkg = callee: overrides: genPkgs (pkgs: pkgs.callPackage callee overrides);

    colors = (import ./lib/colors.nix {inherit (nixpkgs) lib;}).schemes.catppuccin-mocha-sapphire;

    # font = {
    #   name = "IosevkaLyteTerm";
    #   size = 12;
    # };

    # moduleArgs = {
    #   # inherit colors font;
    #   inherit helix slippi hyprland hardware disko home-manager;
    #   inherit (outputs) nixosModules homeManagerModules diskoConfigurations overlays;
    # };

    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev";
  in {
    # kind of a quirk, but package definitions are actually in the "additions"
    # overlay I did this to work around some recursion problems
    # TODO: https://discourse.nixos.org/t/infinite-recursion-getting-started-with-overlays/48880
    packages = genPkgs (pkgs: {inherit (pkgs) iosevkaLyteTerm iosevkaLyteTermSubset;});
    diskoConfigurations = import ./disko;
    templates = import ./templates;
    formatter = genPkgs (p: p.alejandra);

    checks = pkg ({system}: {
      pre-commit-check = pre-commit.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    }) {};

    devShells = pkg ({
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
    }) {};

    overlays = {
      # the default overlay composes all the other overlays together
      default = final: prev: {
        overlays = with overlays; [
          additions
          modifications
          unstable-packages
        ];
      };

      additions = final: prev: let
        iosevkaLyteTerm = prev.callPackage ./packages/iosevkaLyteTerm.nix {};
      in {
        inherit iosevkaLyteTerm;
        iosevkaLyteTermSubset = prev.callPackage ./packages/iosevkaLyteTermSubset.nix {
          inherit iosevkaLyteTerm;
        };
      };

      modifications = final: prev: {
        final.helix = helix.outputs.packages.${prev.system}.helix;
      };

      unstable-packages = final: _prev: {
        unstable-packages = import nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
    };

    nixosModules = import ./modules/nixos {
      inherit home-manager helix nixosModules homeManagerModules pubkey overlays colors sops-nix disko;
      flakeInputs = self.inputs;
    };

    homeManagerModules = import ./modules/home-manager {
      inherit home-manager helix nixosModules homeManagerModules pubkey overlays colors;
      inherit (nixpkgs) lib;
      flakeInputs = self.inputs;
    };

    nixosConfigurations = {
      beefcake = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          hardware.nixosModules.common-cpu-intel

          common
          fonts

          ./nixos/beefcake.nix

          {
            time = {
              timeZone = "America/Chicago";
            };
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      dragon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          outputs.diskoConfigurations.standard
          hardware.nixosModules.common-cpu-amd
          hardware.nixosModules.common-pc-ssd

          common
          password-manager
          wifi
          graphical-workstation
          music-production
          gaming
          slippi.nixosModules.default

          ./nixos/dragon.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                senpai
                iex
                cargo
                firefox-no-tabs
                linux-desktop-environment-config
                slippi.homeManagerModules.default
              ];
            };
          }
        ];
      };

      htpc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          hardware.nixosModules.common-pc-ssd

          common
          graphical-workstation

          ./nixos/htpc.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                linux-desktop-environment-config
              ];
            };
          }
        ];
      };

      foxtrot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          outputs.diskoConfigurations.standard
          hardware.nixosModules.framework-13-7040-amd

          common
          password-manager
          graphical-workstation
          laptop
          gaming

          ./nixos/foxtrot.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                senpai
                iex
                cargo
                firefox-no-tabs
                linux-desktop-environment-config
              ];
            };
          }
        ];
      };

      thablet = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          outputs.diskoConfigurations.standard
          hardware.nixosModules.lenovo-thinkpad-x1-yoga

          common
          password-manager
          graphical-workstation
          laptop
          gaming

          ./nixos/thablet.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                iex
                cargo
                linux-desktop-environment-config
              ];
            };
          }
        ];
      };

      # grablet = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   modules = with nixosModules; [
      #     common

      #     outputs.diskoConfigurations.standard
      #     hardware.nixosModules.common-cpu-intel-kaby-lake
      #     hardware.nixosModules.common-pc-laptopp-ssd
      #     graphical-workstation
      #     laptop
      #     gaming

      #     ./nixos/thablet.nix

      #     {
      #       home-manager.users.daniel = {
      #         imports = with homeManagerModules; [
      #           iex
      #           cargo
      #           linux-desktop-environment-config
      #         ];
      #       };

      #       powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
      #     }
      #   ];
      # };

      thinker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          common
          ./nixos/thinker.nix
        ];
      };

      rascal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          hardware.nixosModules.common-cpu-amd
          common
          ./nixos/rascal.nix
        ];
      };

      router = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          # outputs.diskoConfigurations.unencrypted
          common
          ./nixos/router.nix
        ];
      };
    };

    # TODO: homeconfigs?
    # homeConfigurations = {
    #   # TODO: non-system-specific home configurations?
    #   "deck" = let
    #     system = "x86_64-linux";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with homeManagerModules; [
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
    #       modules = with homeManagerModules; [
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
}
