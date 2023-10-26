{...}: {
  programs.broot = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      modal = false; # vim mode?

      verbs = [
        {
          invocation = "edit";
          shortcut = "e";
          execution = "$EDITOR {file}";
        }
      ];
    };
  };
}
