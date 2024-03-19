{config, ...}: {
  programs.senpai = {
    enable = true;
    config = {
      address = "a";
      nickname = "a";
    };
  };

  home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
    enable = true;
    text = ''
      address irc+insecure://beefcake:6667
      nickname lytedev
      password-cmd pass soju
    '';
  };
}
