{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.tmux-master-service;
in {
  options.services.tmux-master-service = {
    enable = mkEnableOption "tmux master service";

    socket = mkOption {
      type = types.path;
      default = "/run/user/%U/tmux-%U/default";
    };
  };
  config = {
    # https://superuser.com/a/1582196
    systemd.user.services.tmux-master = {
      Unit = {
        Description = "tmux master service";
      };
      Service = {
        Type = "forking";
        RemainAfterExit = "yes";
        ExecStart = "${pkgs.tmux}/bin/tmux -S ${cfg.socket} new-session -d -s default";
        ExecStop = "${pkgs.tmux}/bin/tmux -S ${cfg.socket} kill-session -t weechat";
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
