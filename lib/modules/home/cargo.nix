{ config, ... }:
{
  home.file."${config.home.homeDirectory}/.cargo/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/cargo/config.toml";
}
