{inputs, ...}: {
  imports = [
    {nixpkgs.overlays = [inputs.ssbm.overlay];}
    inputs.ssbm.nixosModules.default
  ];

  ssbm = {
    cache.enable = true;
    overlay.enable = true;

    gcc = {
      rules.enable = true;
      oc-kmod.enable = true;
    };
  };
}
