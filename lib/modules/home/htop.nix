{ config, lib, ... }:
{
  programs.htop.enable = true;

  home.file."${config.xdg.configHome}/htop/htoprc".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/htop/htoprc"
  );
}
