{
  pkgs,
  # self,
  ...
}: {
  elixir-dev = pkgs.mkShell {
    shellHook = "export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive";
    # inputsFrom = [self.packages.${pkgs.system}.my-package];
    buildInputs = with pkgs; [
      elixir
      elixir-ls
      inotify-tools
    ];
  };
}
