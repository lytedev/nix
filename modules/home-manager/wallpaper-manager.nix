{
  pkgs,
  lib,
  ...
}: {
  systemd.user.services.variety = {
    Unit = {
      Description = "Wallapaper downloader and changer";
      After = ["graphical-session.target"];
    };
    Install.WantedBy = ["graphical-session.target"];
    Service = {
      Environment = [
        "PATH=${lib.makeBinPath (with pkgs; [
          variety
          dbus
          (lib.getBin pkgs.plasma5Packages.qttools)
          libsForQt5.kdialog
        ])}"
      ];
      ExecStart = ''
        ${pkgs.variety}/bin/variety
      '';
    };
  };
}
