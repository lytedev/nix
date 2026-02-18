{ config, ... }:
{
  home.file.".iex.exs".source =
    config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/iex/.iex.exs";
}
