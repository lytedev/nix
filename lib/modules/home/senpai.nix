{ lib, config, ... }:
{
  config = lib.mkIf config.lyte.shell.enable {
    programs.senpai = {
      enable = true;
      config = {
        address = "irc+insecure://beefcake.hare-cod.ts.net:6667";
        nickname = "lytedev";
        password-cmd = [
          "pass"
          "soju"
        ];
      };
    };

    home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
      source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/senpai/senpai.scfg"
      );
    };
  };
}
