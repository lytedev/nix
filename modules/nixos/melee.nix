{inputs, ...}: {
  imports = [
    {nixpkgs.overlays = [inputs.ssbm.overlay];}
    inputs.ssbm.nixosModule
  ];

  ssbm = {
    cache.enable = true;
    # overlay.enabled = true;

    gcc = {
      rules.enable = true;
      oc-kmod.enable = true;
    };
  };
}
