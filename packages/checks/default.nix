{
  pkgs,
  git-hooks,
  ...
}: {
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./.;
    hooks = {
      alejandra.enable = true;
    };
  };
}
