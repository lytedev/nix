{inputs, ...}: {
  imports = [
    inputs.ssbm.nixosModule
  ];

  ssbm = {
    cache.enable = true;
    overlay.enabled = true;

    gcc = {
      rules.enable = true;
      oc-kmod.enable = true;
    };
  };
}
