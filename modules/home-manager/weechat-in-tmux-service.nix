{
  pkgs,
  outputs,
  config,
  ...
}: let
  socket = config.services.tmux-master-service.socket;
in {
  imports = with outputs.homeManagerModules; [
    tmux-master-service
  ];
  systemd.user.services.weechat-in-tmux = {
    Unit = {
      Description = "weechat in tmux";
      PartOf = "tmux-master.service";
      After = ["tmux-master.service"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.tmux}/bin/tmux -S ${socket} new-session -d -s weechat ${pkgs.weechat}/bin/weechat";
      ExecStop = "${pkgs.tmux}/bin/tmux -S ${socket} kill-session -t weechat";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
