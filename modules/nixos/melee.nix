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
  imports = [inputs.ssbm.nixosModule];

  ssbm = {
    cache.enable = true;

    gcc = {
      rules.enable = true;
      oc-kmod.enable = true;
    };
  };
}
