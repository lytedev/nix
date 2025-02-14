{ git-hooks, ... }:
{ pkgs, ... }:
{
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./.;
    hooks = {
      nixfmt-rfc-style.enable = true;
    };
  };
}
