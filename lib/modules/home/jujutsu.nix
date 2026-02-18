{
  config,
  lib,
  ...
}:
{
  config = {
    programs.jujutsu = {
      enable = true;
    };

    home.file."${config.xdg.configHome}/jj/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/jujutsu/config.toml"
    );
  };
}
