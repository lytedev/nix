{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    disko.url = "github:nix-community/disko/master";
    sops-nix.url = "github:Mic92/sops-nix";
    helix.url = "github:helix-editor/helix";
    rtx.url = "github:jdx/rtx";
  };

  outputs = inputs @ { self, ... }: {
    diskoConfigurations = import ./disko.nix;

    homeConfigurations =
      # TODO: per arch?
      let
        system = "x86_64-linux";
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      {
        daniel = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            (import
              ./daniel.nix

              pkgs)
          ];
        };
      };
    nixosConfigurations = {
      beefcake = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules =
          [
            ./machines/beefcake.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.daniel = import ./daniel.nix;
            }
          ];
      };

      musicbox = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules =
          [
            inputs.disko.nixosModules.disko
            self.diskoConfigurations.unencrypted
            { _module.args.disks = [ "/dev/sda" ]; }
            ./machines/musicbox.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.daniel = import ./daniel.nix;
            }
          ];
      };

      thinker = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          inputs.disko.nixosModules.disko
          self.diskoConfigurations.standard
          { _module.args.disks = [ "/dev/nvme0n1" ]; }
          ./machines/thinker.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.daniel = import ./daniel.nix;
          }
        ];
      };
    };

    colmena = {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
        };
      };
      defaults = {
        environment.etc."nixos/configuration.nix".text = ''
          throw "sorry, no nixos-rebuild, use colmena"
        '';
      };
      beefcake = {
        deployment = {
          targetHost = "beefcake";
          targetUser = "daniel";
        };
      };
    };
  };
}
