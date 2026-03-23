{ pkgs, ... }:

{
  systemd.tmpfiles.settings."10-notes" = {
    "/storage/notes" = {
      "d" = {
        mode = "0750";
        user = "syncthing";
        group = "syncthing";
      };
    };
  };

  services.restic.commonPaths = [
    "/storage/notes"
  ];

  systemd.timers."notes-autocommit" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  systemd.services."notes-autocommit" = {
    script = ''
      cd /storage/notes
      if [ ! -d .git ]; then
        git init
        git add -A
        git commit -m "initial commit"
      fi
      git add -A
      if ! git diff --cached --quiet; then
        git commit -m "auto: $(date -Iseconds)"
      fi
    '';
    path = with pkgs; [ git ];
    serviceConfig = {
      Type = "oneshot";
      User = "syncthing";
      WorkingDirectory = "/storage/notes";
    };
  };
}
