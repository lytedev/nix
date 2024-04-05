{inputs, ...}: {
  imports = [
    # {nixpkgs.overlays = [inputs.ssbm.overlay];}
    # inputs.ssbm.homeManagerModules.default
  ];

  # ssbm = {
  #   slippi-launcher = {
  #     enable = false;
  #     launchMeleeOnPlay = false;
  #   };
  # };
}
