{ self, ... }:
let
  forSelfOverlay =
    if builtins.hasAttr "overlays" self && builtins.hasAttr "forSelf" self.overlays then
      self.overlays.forSelf
    else
      (_: p: p);
in
rec {
  systems = [
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
  ];
  forSystems = nixpkgs: nixpkgs.lib.genAttrs systems;
  pkgsFor = nixpkgs: system: (import nixpkgs { inherit system; }).extend forSelfOverlay;
  genPkgs = nixpkgs: func: (forSystems nixpkgs (system: func (pkgsFor nixpkgs system)));
}
