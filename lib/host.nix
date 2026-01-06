inputs:
let
  baseHost =
    {
      nixpkgs,
      home-manager,
      nixosSystem ? nixpkgs.lib.nixosSystem,
      extraModules ? [ ],
      extraOverlays ? [ ],
      extraImports ? [ ],
      ...
    }:
    (
      path:
      (
        {
          system ? "x86_64-linux",
        }:
        (nixosSystem {
          inherit system;
          specialArgs = {
            inherit home-manager;
            hardware = inputs.hardware.outputs.nixosModules;
            diskoConfigurations = inputs.self.outputs.diskoConfigurations;
          };
          modules = [
            {
              imports = extraImports;
              nixpkgs.overlays = extraOverlays;
            }
          ]
          ++ extraModules
          ++ [
            inputs.self.outputs.nixosModules.default
            (import path)
          ];
        })
      )
    );
  stable = { inherit (inputs) nixpkgs home-manager; };
  unstable = {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
  };
  # mobile-nixos host helper - takes device name and config path
  # https://uninsane.org/blog/mobile-nixos-pinephone/
  mobileHost =
    device: path:
    unstable.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        home-manager = inputs.home-manager-unstable;
        hardware = inputs.hardware.outputs.nixosModules;
        diskoConfigurations = inputs.self.outputs.diskoConfigurations;
      };
      modules = [
        (import "${inputs.mobile-nixos}/lib/configuration.nix" {
          inherit device;
        })
        inputs.self.outputs.nixosModules.default
        (import path)
        { nixpkgs.config.allowUnfree = true; }
      ];
    };
in
{
  inherit baseHost stable unstable mobileHost;
  stableHost = baseHost stable;
  host = baseHost unstable;
  steamdeckHost = baseHost (
    unstable
    // {
      extraModules = [
        inputs.jovian.outputs.nixosModules.default
        inputs.self.nixosModules.steamdeck
      ];
      # do NOT manually include the jovian overlay here
    }
  );
}
