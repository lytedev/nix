{ self, ... }:
{ pkgs, ... }:
{
  default = pkgs.mkShell {
    inherit (self.outputs.checks.${pkgs.system}.git-hooks) shellHook;
    packages = with pkgs; [
      colmena
      nil
      nixd
      nixfmt-rfc-style
      lua-language-server
      nodePackages.bash-language-server
      markdown-oxide
    ];
  };
}
