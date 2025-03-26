{ self, ... }@inputs:
let
  forSelfOverlay =
    if builtins.hasAttr "overlays" self && builtins.hasAttr "forSelf" self.overlays then
      self.overlays.forSelf
    else
      (_: p: p);
in
rec {
  inherit forSelfOverlay;
  systems = [
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
  ];
  forSystems = nixpkgs: nixpkgs.lib.genAttrs systems;
  pkgsFor = nixpkgs: system: (import nixpkgs { inherit system; }).extend forSelfOverlay;
  genPkgs = nixpkgs: func: (forSystems nixpkgs (system: func (pkgsFor nixpkgs system)));

  conditionalOutOfStoreSymlink =
    config: outOfStoreSymlink: relPath:
    if config.lyte.useOutOfStoreSymlinks.enable then
      config.lib.file.mkOutOfStoreSymlink outOfStoreSymlink
    else
      relPath;

  inherit (import ./host.nix inputs)
    host
    stableHost
    steamdeckHost
    baseHost
    ;

  uGenPkgs = genPkgs inputs.nixpkgs-unstable;

  deployChecks = builtins.mapAttrs (
    system: deployLib: deployLib.deployChecks self.deploy
  ) inputs.deploy-rs.lib;

}
