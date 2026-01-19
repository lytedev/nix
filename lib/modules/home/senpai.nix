{ lib, config, ... }:
{
  config = lib.mkIf config.lyte.shell.enable {
    programs.senpai = {
      enable = true;
      config = {
        address = "irc+insecure://beefcake.hare-cod.ts.net:6667";
        nickname = "lytedev";
        password-cmd = [
          # TODO: update to use bitwarden-cli?
          "pass"
          "soju"
        ];
      };
    };

    home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
      enable = true;
      # TODO: update to use bitwarden-cli?
      text = ''
        address irc+insecure://beefcake:6667
        nickname lytedev
        password-cmd pass soju
      '';
    };
  };
}
