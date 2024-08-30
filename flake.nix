{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    helix.url = "github:helix-editor/helix/master";
    hardware.url = "github:nixos/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland";

    slippi.url = "github:lytedev/slippi-nix";
    # slippi.url = "git+file:///home/daniel/code/open-source/slippi-nix";
    slippi.inputs.nixpkgs.follows = "nixpkgs-unstable";
    slippi.inputs.home-manager.follows = "home-manager-unstable";

    # nnf.url = "github:thelegy/nixos-nftables-firewall?rev=71fc2b79358d0dbacde83c806a0f008ece567b7b";
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
    git-hooks,
    home-manager,
    home-manager-unstable,
    helix,
    hardware,
    # nnf,
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

    unstable = {
      forSystems = nixpkgs-unstable.lib.genAttrs systems;
      pkgsFor = system: (import nixpkgs-unstable {inherit system;}).extend overlays.default;
      genPkgs = func: (forSystems (system: func (pkgsFor system)));
      pkg = callee: overrides: genPkgs (pkgs: pkgs.callPackage callee overrides);
    };

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
    packages = genPkgs (pkgs: {inherit (pkgs) iosevkaLyteTerm iosevkaLyteTermSubset nix-base-container-image;});
    diskoConfigurations = import ./disko;
    templates = import ./templates;
    formatter = genPkgs (p: p.alejandra);

    checks = genPkgs ({system, ...}: {
      git-hooks = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    });

    devShells = genPkgs ({
      system,
      pkgs,
      mkShell,
      ...
    }: {
      default = mkShell {
        inherit (outputs.checks.${system}.git-hooks) shellHook;
        packages = with pkgs; [
          lua-language-server
          nodePackages.bash-language-server
        ];
      };
    });

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
        nix-base-container-image = final.dockerTools.buildImageWithNixDb {
          name = "git.lyte.dev/lytedev/nix";
          tag = "latest";

          copyToRoot = with final; [
            bash
            coreutils
            curl
            gawk
            gitFull
            git-lfs
            gnused
            nodejs
            wget
            sudo
            nixFlakes
            cacert
            gnutar
            gzip
            openssh
            xz
            (pkgs.writeTextFile {
              name = "nix.conf";
              destination = "/etc/nix/nix.conf";
              text = ''
                accept-flake-config = true
                experimental-features = nix-command flakes
                build-users-group =
                substituters = https://nix.h.lyte.dev https://cache.nixos.org/
                trusted-substituters = https://nix.h.lyte.dev https://cache.nixos.org/
                trusted-public-keys = h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
              '';
            })
          ];

          extraCommands = ''
            # enable /usr/bin/env for scripts
            mkdir -p usr
            ln -s ../bin usr/bin

            # create /tmp
            mkdir -p tmp

            # create HOME
            mkdir -vp root
          '';
          config = {
            Cmd = ["/bin/bash"];
            Env = [
              "LANG=en_GB.UTF-8"
              "ENV=/etc/profile.d/nix.sh"
              "BASH_ENV=/etc/profile.d/nix.sh"
              "NIX_BUILD_SHELL=/bin/bash"
              "PAGER=cat"
              "PATH=/usr/bin:/bin"
              "SSL_CERT_FILE=${final.cacert}/etc/ssl/certs/ca-bundle.crt"
              "USER=root"
            ];
          };
        };
      };

      modifications = final: prev: rec {
        helix = helix.outputs.packages.${prev.system}.helix;
        final.helix = helix;
        # TODO: would love to use a current wezterm build so I can make use of ssh/mux functionality without breakage
        # source: https://github.com/wez/wezterm/issues/3771
        wezterm = prev.wezterm.overrideAttrs rec {
          version = "56a27e93a9ee50aab50ff4d78308f9b3154b5122";
          src = prev.fetchFromGitHub {
            owner = "wez";
            repo = "wezterm";
            rev = version;
            fetchSubmodules = true;
            hash = "sha256-zl0Me24ncrpXUCvkQHlbgUucf0zrkhFFI242wsSQKLw=";
          };
          # cargoLockFile = null;
          cargoHash = "";
        };
        final.wezterm = wezterm;
      };

      unstable-packages = final: _prev: {
        unstable-packages = import nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
    };

    nixosModules = import ./modules/nixos {
      inherit home-manager home-manager-unstable helix nixosModules homeManagerModules pubkey overlays colors sops-nix disko;
      flakeInputs = self.inputs;
    };

    homeManagerModules = import ./modules/home-manager {
      inherit home-manager home-manager-unstable helix nixosModules homeManagerModules pubkey overlays colors;
      inherit (nixpkgs) lib;
      flakeInputs = self.inputs;
    };

    nixosConfigurations = {
      beefcake = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-defaults

          hardware.nixosModules.common-cpu-intel

          common
          linux
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

      dragon = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

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

      bigtower = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

          outputs.diskoConfigurations.unencrypted
          hardware.nixosModules.common-cpu-amd
          hardware.nixosModules.common-pc-ssd

          common
          # wifi
          graphical-workstation
          music-production
          gaming

          ./nixos/bigtower.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                firefox-no-tabs
                linux-desktop-environment-config
              ];
            };
          }
        ];
      };

      htpc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-defaults

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

      foxtrot = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

          outputs.diskoConfigurations.standard
          hardware.nixosModules.framework-13-7040-amd

          common
          password-manager
          graphical-workstation
          laptop
          gaming

          ./nixos/foxtrot.nix

          ({pkgs, ...}: {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                senpai
                iex
                cargo
                firefox-no-tabs
                linux-desktop-environment-config
              ];
            };
            environment.systemPackages = with pkgs; [
              fw-ectool
              (writeShellApplication
                {
                  name = "reset-wifi-module";
                  runtimeInputs = with pkgs; [kmod];
                  text = ''
                    modprobe -rv mt7921e
                    modprobe -v mt7921e
                  '';
                })
            ];
          })
        ];
      };

      thablet = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults
          outputs.diskoConfigurations.standard
          hardware.nixosModules.lenovo-thinkpad-x1-yoga

          common
          password-manager
          graphical-workstation
          music-production
          laptop
          gaming

          ./nixos/thablet.nix

          {
            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                senpai
                iex
                cargo
                firefox-no-tabs
                linux-desktop-environment-config
                # slippi.homeManagerModules.default
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

      thinker = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

          {
            _module.args = {
              disks = ["/dev/nvme0n1"];
              swapSize = "32G";
            };
          }
          outputs.diskoConfigurations.standardWithHibernateSwap
          hardware.nixosModules.lenovo-thinkpad-t480
          hardware.nixosModules.common-pc-laptop-ssd

          music-production
          common
          password-manager
          graphical-workstation
          laptop
          gaming

          ./nixos/thinker.nix

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

      musicbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-defaults

          {
            _module.args = {
              disks = ["/dev/sda"];
              # swapSize = "8G";
            };
          }
          outputs.diskoConfigurations.unencrypted
          hardware.nixosModules.common-pc-laptop-ssd

          music-production
          common
          graphical-workstation
          wifi

          # ./nixos/musicbox.nix

          {
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
            hardware.bluetooth.enable = true;
            networking.networkmanager.enable = true;

            home-manager.users.daniel = {
              imports = with homeManagerModules; [
                firefox-no-tabs
                linux-desktop-environment-config
              ];
            };
          }
        ];
      };

      rascal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-defaults
          hardware.nixosModules.common-cpu-amd
          common
          ./nixos/rascal.nix
        ];
      };

      router = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-defaults
          outputs.diskoConfigurations.unencrypted
          common
          linux
          troubleshooting-tools

          # NOTE: maybe use this someday, but I think I need more concrete
          # networking knowledge before I know how to use it well. Additionally,
          # I can use my existing firewall configuration more easily if I manage
          # it directly.
          # nnf.nixosModules.default

          ./nixos/router.nix
        ];
      };
    };

    homeConfigurations = {
      "deck" = let
        system = "x86_64-linux";
        pkgs = unstable.pkgsFor system;
      in
        home-manager-unstable.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = with homeManagerModules; [
            common
            {
              home = {
                homeDirectory = "/home/deck";
                username = "deck";
                stateVersion = "24.11";
              };
            }
            {
              home.packages = with pkgs; [
                ludusavi
                rclone
              ];
            }
            linux
          ];
        };
    };

    # TODO: nix-on-droid for phone terminal usage?
    # TODO: nix-darwin for work?
    # TODO: nixos ISO?
  };
}
