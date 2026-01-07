{
  nixpkgs-unstable,
  nixpkgs,
  self,
  ...
}:
let
  inherit (self) outputs;
  inherit (outputs) nixosModules;
in
{
  beefcake =
    let
      system = "x86_64-linux";
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = with nixosModules; [
        home-manager-defaults
        conduwuit

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

      outputs.diskoConfigurations.unencrypted
      hardware.nixosModules.common-pc-ssd
      common
      gaming
      graphical-workstation
      # plasma6

      jovian.outputs.nixosModules.jovian

      {
        networking.hostName = "steamdeck1";
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        hardware.bluetooth.enable = true;
        networking.networkmanager.enable = true;

        home-manager.users.daniel = {
          imports = with homeManagerModules; [
            linux-desktop-environment-config
          ];
        };
      }
    ];
  };

  thablet = nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with nixosModules; [
      home-manager-unstable-defaults
      {
        _module.args = {
          disk = "nvme0n1";
          esp = {
            label = "ESP";
            size = "4G";
            name = "ESP";
          };
        };
      }
      outputs.diskoConfigurations.standard
      hardware.nixosModules.lenovo-thinkpad-x1-yoga

      common
      password-manager
      graphical-workstation
      # plasma6
      music-production
      laptop
      touchscreen
      gaming

      ./nixos/thablet.nix

      {
        home-manager.users.daniel = {
          imports = with homeManagerModules; [
            senpai
            iex
            cargo
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

  musicbox = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with nixosModules; [
      home-manager-defaults

      {
        _module.args = {
          disks = [ "/dev/sda" ];
          # swapSize = "8G";
        };
        esp = { };
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

  pinephone =
    let
      inherit (nixpkgs-unstable) lib;
    in
    lib.nixosSystem {
      system = "aarch64-linux";

      modules = with nixosModules; [
        {
          imports = [
            (import "${mobile-nixos}/lib/configuration.nix" {
              device = "pine64-pinephone";
            })
          ];

          nixpkgs.buildPlatform = "x86_64-linux";

          # TODO: quirk: since the pinephone kernel doesn't seem to have "rpfilter" support, firewall ain't working
          networking.firewall.enable = lib.mkForce false;

          # TODO: quirk: since git send-email requires perl support, which we don't seem to have on the pinephone, we're just disabling git for now
          programs.git.enable = lib.mkForce false;

          # bootloader config from sd-image module
          boot.loader.generic-extlinux-compatible.enable = lib.mkForce true;

          # use wpa_supplicant for wifi (NetworkManager conflicts with networking.wireless)
          networking.networkmanager.enable = lib.mkForce false;
          networking.wireless.enable = lib.mkForce true;

          # Mobile/Phosh configuration
          lyte.mobile = {
            enable = true;
            user = "daniel";
            scale = 1.5; # 1.5 works well for PinePhone, 2.0 is too zoomed
          };

          # Host identification
          networking.hostName = "pinephone";
        }

        # SD card image builder
        "${nixpkgs-unstable}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"

        linux
        home-manager-unstable-defaults
        common
        wifi
        mobile

        # Home-manager mobile configuration
        {
          home-manager.users.daniel = {
            imports = [ self.outputs.homeManagerModules.mobile ];
            lyte.mobile.enable = true;
          };
        }

        {
          system.stateVersion = "24.11";
        }
      ];
    };
}
