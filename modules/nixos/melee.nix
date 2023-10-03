{
  # flake,
  inputs,
  # outputs,
  # lib,
  # config,
  # pkgs,
  system,
  # modulesPath,
  ...
}: {
  imports = [inputs.ssbm.nixosModule];

  environment = {
    systemPackages = with inputs.ssbm.packages.${system}; [
      slippi-netplay
      slippi-playback
    ];
  };

  ssbm = {
    cache.enable = true;

    gcc = {
      rules.enable = true;
      oc-kmod.enable = true;
    };
  };
}
