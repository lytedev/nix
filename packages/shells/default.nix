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

  music-production = pkgs.mkShell {
    # TODO: reaper? VSTs like Helm? Neural Amp modeler for guitar?
    # I would love to be able to do basic recording and editing as well as live "performances" with effects chains etc.
  };
}
