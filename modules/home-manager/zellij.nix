{
  programs.zellij = {
    # TODO: enable after port config
    enable = false;
    enableFishIntegration = true;
    settings = {
      pane_frames = false;
      # TODO: port config
    };
  };

  home.shellAliases = {
    z = "zellij";
  };
}
