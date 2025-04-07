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
}
