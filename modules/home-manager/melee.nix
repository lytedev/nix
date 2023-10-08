{
  # flake,
  inputs,
  # outputs,
  # lib,
  # config,
  # pkgs,
  # system,
  # modulesPath,
  ...
}: {
  imports = [
    {
      nixpkgs.overlays = [inputs.ssbm.overlay];
    }
    inputs.ssbm.homeManagerModule
  ];

  ssbm = {
    slippi-launcher = {
      enable = true;
    };
  };
}
