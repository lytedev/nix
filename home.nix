inputs @ { nixpkgs, home-manager, ... }:
let
  system = "x86_64-linux";
  overlay = final: prev: {
    helix = prev.helix // inputs.helix.packages.${system}.helix;
    rtx = prev.rtx // inputs.rtx.packages.${system}.rtx;
  };
  pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
in {
  # TODO: per arch?
  daniel = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [ import ./daniel.nix pkgs ];
  };
}
