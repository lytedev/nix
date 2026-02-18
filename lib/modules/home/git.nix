{
  config,
  lib,
  ...
}:
{
  programs.git = {
    enable = !config.lyte.shell.learn-jujutsu-not-git.enable;

    lfs = {
      enable = true;
    };

    settings = {
      include.path = "${config.xdg.configHome}/git/config.local";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = { };
  };

  home.file."${config.xdg.configHome}/git/config.local".source =
    config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/git/config.local";
}
