{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    inherit (import nix/boilerplate.nix inputs) call;
  in {
    overlays = import nix/overlays.nix;
    packages = call (import nix/packages.nix);
    checks = call (import nix/checks.nix);
    devShells = call (import nix/shells.nix);
  };
}
