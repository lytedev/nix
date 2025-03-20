inputs:
let
  baseHost =
    {
      nixpkgs,
      home-manager,
      extraModules ? [ ],
      extraOverlays ? [ ],
      ...
    }:
    (
      path:
      (
        {
          system ? "x86_64-linux",
        }:
        (nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit home-manager;
            hardware = inputs.hardware.outputs.nixosModules;
            diskoConfigurations = inputs.self.outputs.diskoConfigurations;
          };
          modules =
            [
              {
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
in
{
  stableHost = baseHost { inherit (inputs) nixpkgs home-manager; };
  host = baseHost {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
  };
  steamdeckHost = baseHost {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
    extraModules = [ inputs.jovian.outputs.nixosModules.default ];
    # do NOT manually include the jovian overlay here
  };
}
