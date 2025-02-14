{
  self,
  pkgs,
  ...
}: {
  default = pkgs.mkShell {
    inherit (self.outputs.checks.${pkgs.system}.git-hooks) shellHook;
    packages = with pkgs; [
      lua-language-server
      nodePackages.bash-language-server
    ];
  };
}
