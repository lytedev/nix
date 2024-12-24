{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.git-hooks.url = "github:cachix/git-hooks.nix";
  inputs.git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  outputs = inputs: let
    inherit (import nix/boilerplate.nix inputs) fullImport genPkgs;
  in {
    # overlays = import nix/overlays.nix;
    checks = fullImport nix/checks.nix;
    packages = fullImport nix/packages.nix;
    devShells = fullImport nix/shells.nix;
    formatter = genPkgs (p: p.alejandra);
  };
}
