{
  pkgs,
  self,
  ...
}:
{
  elixir-dev = pkgs.mkShell {
    shellHook = ''
      ${self.checks.${pkgs.system}.git-hooks.shellHook}
      export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive
    '';
    # inputsFrom = [self.packages.${pkgs.system}.my-package];
    buildInputs = with pkgs; [
      elixir
      elixir-ls
      inotify-tools
    ];
    MIX_ENV = "dev";
  };
  default = self.outputs.devShells.${pkgs.system}.elixir-dev;
}
