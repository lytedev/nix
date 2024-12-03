{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    # sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    helix.url = "github:helix-editor/helix/master";
    hardware.url = "github:nixos/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland";

    wezterm.url = "github:wez/wezterm?dir=nix";
    wezterm.inputs.nixpkgs.follows = "nixpkgs-unstable";

    slippi.url = "github:lytedev/slippi-nix";
    # slippi.url = "git+file:///home/daniel/code/open-source/slippi-nix";
    slippi.inputs.nixpkgs.follows = "nixpkgs-unstable";
    slippi.inputs.home-manager.follows = "home-manager-unstable";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/development";
    jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nnf.url = "github:thelegy/nixos-nftables-firewall?rev=71fc2b79358d0dbacde83c806a0f008ece567b7b";

    mobile-nixos = {
      url = "github:lytedev/mobile-nixos";
      flake = false;
    };
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
      "h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M="
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
    wezterm,
    home-manager,
    home-manager-unstable,
    helix,
    hardware,
    jovian,
    mobile-nixos,
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

    style = {
      colors = (import ./lib/colors.nix {inherit (nixpkgs) lib;}).schemes.catppuccin-mocha-sapphire;

      font = {
        name = "IosevkaLyteTerm";
        size = 12;
      };
    };

    /*
    moduleArgs = {
      # inherit style;
      inherit helix slippi hyprland hardware disko home-manager;
      inherit (outputs) nixosModules homeManagerModules diskoConfigurations overlays;
    };
    */

    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev";
  in {
    /*
    kind of a quirk, but package definitions are actually in the "additions"
    overlay I did this to work around some recursion problems
    TODO: https://discourse.nixos.org/t/infinite-recursion-getting-started-with-overlays/48880
    */
    packages = genPkgs (pkgs: {inherit (pkgs) iosevkaLyteTerm iosevkaLyteTermSubset nix-base-container-image;});
    diskoConfigurations = import ./disko {inherit (nixpkgs) lib;};
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
            nixVersions.stable
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

      modifications = final: prev: let
        wezterm-input = wezterm;
      in rec {
        helix = helix.outputs.packages.${prev.system}.helix;
        final.helix = helix;
        /*
        TODO: would love to use a current wezterm build so I can make use of ssh/mux functionality without breakage
        source: https://github.com/wez/wezterm/issues/3771
        not-yet-merged (abandoned?): https://github.com/wez/wezterm/pull/4737
        I did try using the latest code via the flake, but alas it did not resolve my issues with mux'ing
        */
        wezterm = wezterm-input.outputs.packages.${prev.system}.default;
        # wezterm = (import nixpkgs {inherit (prev) system;}).wezterm;
        final.wezterm = wezterm;

        # zellij = prev.zellij.overrideAttrs rec {
        #   version = "0.41.0";
        #   src = prev.fetchFromGitHub {
        #     owner = "zellij-org";
        #     repo = "zellij";
        #     rev = "v0.41.0";
        #     hash = "sha256-A+JVWYz0t9cVA8XZciOwDkCecsC2r5TU2O9i9rVg7do=";
        #   };
        #   cargoDeps = prev.zellij.cargoDeps.overrideAttrs (prev.lib.const {
        #     name = "zellij-vendor.tar.gz";
        #     inherit src;
        #     outputHash = "sha256-WxrMI7fV0pNsGjbNpXLr+xnMdWYkC4WxIeN4OK3ZPIE=";
        #   });
        # };
        # final.zellij = zellij;
      };

      unstable-packages = final: _prev: {
        unstable-packages = import nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
    };

    nixosModules = import ./modules/nixos {
      inherit home-manager home-manager-unstable helix nixosModules homeManagerModules pubkey overlays style sops-nix disko;
      flakeInputs = self.inputs;
    };

    homeManagerModules = import ./modules/home-manager {
      inherit home-manager home-manager-unstable helix nixosModules homeManagerModules pubkey overlays style;
      inherit (nixpkgs) lib;
      flakeInputs = self.inputs;
    };

    nixosConfigurations = {
      beefcake = let
        system = "x86_64-linux";
      in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = with nixosModules; [
            home-manager-defaults

            # TODO: disko?
            hardware.nixosModules.common-cpu-intel

            outputs.nixosModules.deno-netlify-ddns-client
            {
              services.deno-netlify-ddns-client = {
                enable = true;
                username = "beefcake.h";
                # TODO: router doesn't even do ipv6 yet...
                ipv6 = false;
              };
            }

            family-users
            common
            podman
            troubleshooting-tools
            virtual-machines
            virtual-machines-gui
            linux
            fonts

            ./nixos/beefcake.nix

            {
              services.kanidm.package = (unstable.pkgsFor system).kanidm;
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
          virtual-machines
          virtual-machines-gui
          music-production
          plasma6
          gaming
          slippi.nixosModules.default

          outputs.nixosModules.deno-netlify-ddns-client
          {
            services.deno-netlify-ddns-client = {
              enable = true;
              username = "dragon.h";
              # TODO: router doesn't even do ipv6 yet...
              ipv6 = false;
            };
          }

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
          gaming
          graphical-workstation
          plasma6

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

      steamdeck1 = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

          outputs.diskoConfigurations.standard
          hardware.nixosModules.common-pc-ssd
          common
          gaming
          graphical-workstation
          plasma6

          jovian.outputs.nixosModules.jovian

          {
            networking.hostName = "steamdeck1";
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

      foxtrot = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          home-manager-unstable-defaults

          outputs.diskoConfigurations.standard
          hardware.nixosModules.framework-13-7040-amd

          common
          kde-connect
          password-manager
          graphical-workstation
          plasma6
          virtual-machines
          virtual-machines-gui
          laptop
          gaming
          cross-compiler

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
              (writeShellApplication
                {
                  name = "perfmode";
                  # we use command -v $cmd here because we only want to invoke these calls _if_ the related package is installed on the system
                  # otherwise, they will likely have no effect anyways
                  text = ''
                    command -v powerprofilesctl &>/dev/null && bash -x -c 'powerprofilesctl set balanced'
                    command -v swaymsg &>/dev/null && bash -x -c 'swaymsg output eDP-1 mode 2880x1920@120Hz'
                  '';
                })
              (writeShellApplication
                {
                  name = "battmode";
                  text = ''
                    command -v powerprofilesctl &>/dev/null && bash -x -c 'powerprofilesctl set power-saver'
                    command -v swaymsg &>/dev/null && bash -x -c 'swaymsg output eDP-1 mode 2880x1920@60Hz'
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
          plasma6
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

      /*
      grablet = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with nixosModules; [
          common

          outputs.diskoConfigurations.standard
          hardware.nixosModules.common-cpu-intel-kaby-lake
          hardware.nixosModules.common-pc-laptopp-ssd
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

            powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
          }
        ];
      };
      */

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
          linux
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

          outputs.nixosModules.deno-netlify-ddns-client
          {
            services.deno-netlify-ddns-client = {
              enable = true;
              username = "router.h";
              # TODO: ipv6
              ipv6 = false;
            };
          }

          /*
          NOTE: maybe use this someday, but I think I need more concrete
          networking knowledge before I know how to use it well. Additionally,
          I can use my existing firewall configuration more easily if I manage
          it directly.
          nnf.nixosModules.default
          */

          ./nixos/router.nix
        ];
      };

      # pinephone-image =
      #   (import "${mobile-nixos}/lib/eval-with-configuration.nix" {
      #     configuration = with nixosModules; [
      #       linux
      #       home-manager-defaults

      #       # outputs.diskoConfigurations.unencrypted # can I even disko with an image-based installation?
      #       common
      #       wifi

      #       # TODO: how do I get a minimally useful mobile environment?
      #       # for me, this means an on-screen keyboard and suspend support I think?
      #       # I can live in a tty if needed and graphical stuff can all evolve later
      #       # not worried about modem
      #       # maybe/hopefully I can pull in or define my own sxmo via nix?
      #     ];
      #     device = "pine64-pinephone";
      #     pkgs = pkgsFor "aarch64-linux";
      #   })
      #   .outputs
      #   .disk-image;

      pinephone = let
        inherit (nixpkgs-unstable) lib;
      in
        lib.nixosSystem {
          system = "aarch64-linux";
          # lib.nixosSystem {

          modules = with nixosModules; [
            {
              imports = [
                (import "${mobile-nixos}/lib/configuration.nix" {
                  device = "pine64-pinephone";
                })
              ];

              # nixpkgs.hostPlatform.system = "aarch64-linux";
              nixpkgs.buildPlatform = "x86_64-linux";

              # TODO: quirk: since the pinephone kernel doesn't seem to have "rpfilter" support, firewall ain't working
              networking.firewall.enable = lib.mkForce false;

              # TODO: quirk: since git send-email requires perl support, which we don't seem to have on the pinephone, we're just disabling git for now
              # TODO: would likely be easier/better to somehow ignore the assertion? probably a way to do that...
              programs.git.enable = lib.mkForce false;

              # this option is conflicted, presumably due to some assumption in my defaults/common config
              # the sd-image module we're importing above has this set to true, so we better go with that?
              # that said, I think the mobile-nixos bootloader module has this set to false, so...
              # TODO: what does this mean?
              boot.loader.generic-extlinux-compatible.enable = lib.mkForce true;

              # another conflicting option since I think I default to NetworkManager and this conflicts with networking.wireless.enable
              networking.networkmanager.enable = lib.mkForce false;
              networking.wireless.enable = lib.mkForce true;
            }

            # TODO: how do I build this as a .img to flash to an SD card?

            # for testing, this seems to work `nixos-rebuild build --impure --flake .#pinephone`

            # TODO: would like to use the mobile-nixos installer?
            "${nixpkgs-unstable}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"

            linux
            home-manager-unstable-defaults

            # outputs.diskoConfigurations.unencrypted # can I even disko with an image-based installation?
            common
            wifi

            {
              system.stateVersion = "24.11";
            }

            {
              # nixpkgs.buildPlatform = "x86_64-linux";
              # nixpkgs.hostPlatform = lib.systems.examples.aarch64-multiplatform;
              # nixpkgs.localSystem.system = lib.systems.examples.x86_64-linux;
              # nixpkgs.crossSystem = lib.mkForce null;
            }
          ];
        };
    };

    images.pinephone = outputs.nixosConfigurations.pinephone.config.system.build.sdImage;

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

    /*
    TODO: nix-on-droid for phone terminal usage? mobile-nixos?
    TODO: nix-darwin for work?
    TODO: nixos ISO?
    */
  };
}
