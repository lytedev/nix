inputs @ {
  nixpkgs,
  nixpkgs-unstable,
  self,
  ...
}: let
  /*
  *
  include a "forSelf" overlay from the flake's own outputs if one exists

  */
  forSelfOverlay =
    if builtins.hasAttr "overlays" self && builtins.hasAttr "forSelf" self.overlays
    then self.overlays.forSelf
    else (_: p: p);

  # a wrapper function that produces the boilerplate functions so we can define
  # them for both nixpkgs and nixpkgs-unstable
  buildFuncs = nixpkgs: rec {
    systems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: ((import nixpkgs {inherit system;}).extend forSelfOverlay);
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
    call = imported: genPkgs (pkgs: imported (inputs // {inherit pkgs;}));
  };
in
  (buildFuncs nixpkgs)
  // {
    unstable = buildFuncs nixpkgs-unstable;
  }
