{ config, lib, ... }:
{
  config = lib.mkIf config.programs.zellij.enable {
    programs.zellij = {
      # do not start immediately
      enableFishIntegration = false;
    };

    home.file."${config.xdg.configHome}/zellij/config.kdl".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/zellij/config.kdl"
    );
  };
}
