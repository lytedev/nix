{
  git-hooks,
  pkgs,
  ...
}: {
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./..;
    hooks = {
      alejandra.enable = true;
      convco.enable = true;
      credo.enable = true;
      dialyzer.enable = true;
      mix-format.enable = true;
      mix-test.enable = true;
    };
  };
}
