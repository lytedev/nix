{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs: let
    inherit (import nix/boilerplate.nix inputs) call;
  in {
    overlays = import nix/overlays.nix;
    packages = call (import nix/packages.nix);
    devShells = call (import nix/shells.nix);
  };
}
