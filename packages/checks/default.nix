{ git-hooks, ... }:
{ pkgs, ... }:
{
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./.;
    hooks = {
      convco.enable = true;
      nixfmt-rfc-style.enable = true;
    };
  };
}
