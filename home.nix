inputs:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
in
{
  # TODO: per arch?
  daniel = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      (import
        ./daniel.nix

        pkgs)
    ];
  };
}
