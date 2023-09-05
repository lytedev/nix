{
  inputs =
    let
      followedInput = url: {
        url = url;
        inputs.nixpkgs.follows = "nixpkgs";
      };
    in
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

      # TODO: this could be a release tarball? fully recompiling this on every change suuuucks
      api-lyte-dev = followedInput "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";

      home-manager = followedInput "github:nix-community/home-manager/release-23.05";
      disko = followedInput "github:nix-community/disko/master"; # NOTE: lock update!
      sops-nix = followedInput "github:Mic92/sops-nix";
      helix = followedInput "github:helix-editor/helix";
    };

  outputs = { self, ... }@inputs: {
    diskoConfigurations = import ./disko.nix;
    homeConfigurations =
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
            ./machines/musicbox-disks.nix
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
          ./machines/thinker-disks.nix
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
      musicbot = inputs.nixpkgs.lib.nixosSystem {
        deployment = {
          targetHost = "musicbox";
          targetPort = 1234;
          targetUser = "nixos";
        };
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules =
          [
            inputs.disko.nixosModules.disko
            ./machines/musicbox-disks.nix
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
    };
  };
}
