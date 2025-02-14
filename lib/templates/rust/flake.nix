{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.git-hooks.url = "github:cachix/git-hooks.nix";
  inputs.git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  outputs = inputs: let
    inherit (import nix/boilerplate.nix inputs) call genPkgs;
  in {
    # overlays = import nix/overlays.nix;
    checks = call (import nix/checks.nix);
    packages = call (import nix/packages.nix);
    devShells = call (import nix/shells.nix);
    formatter = genPkgs (p: p.alejandra);
  };
}
