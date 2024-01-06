{inputs, ...}: {
  imports = [
    {nixpkgs.overlays = [inputs.ssbm.overlay];}
    inputs.ssbm.homeManagerModule
  ];

  ssbm = {
    slippi-launcher = {
      enable = true;
      launchMeleeOnPlay = false;
    };
  };
}
