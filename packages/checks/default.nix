{ git-hooks, ... }:
{ pkgs, ... }:
{
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./.;
    hooks = {
      convco.enable = true;
      nixfmt-rfc-style.enable = true;
      # nix-flake-check = {
      #   enable = true;
      #   name = "nix flake check";
      #   entry = "${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command flakes' flake check";
      #   pass_filenames = false;
      #   stages = [ "pre-commit" ];
      # };
    };
  };
}
