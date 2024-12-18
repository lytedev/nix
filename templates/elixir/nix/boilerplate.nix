inputs @ {
  nixpkgs,
  self,
  ...
}: let
  forSelfOverlay =
    if builtins.hasAttr "forSelf" self.overlays
    then self.overlays.forSelf
    else (_: p: p);
in rec {
  systems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
  forSystems = nixpkgs.lib.genAttrs systems;
  pkgsFor = system: ((import nixpkgs {inherit system;}).extend forSelfOverlay);
  genPkgs = func: (forSystems (system: func (pkgsFor system)));
  call = imported: genPkgs (pkgs: imported (inputs // {inherit pkgs;}));
}
