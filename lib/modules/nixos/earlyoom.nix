{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lyte.oom-killer;
in
{
  options.lyte.oom-killer = {
    enable = lib.mkOption {
      default = config.lyte.desktop.enable;
      description = "Enable earlyoom to prevent workstation OOM lockups.";
      type = lib.types.bool;
    };
  };

  config = lib.mkIf cfg.enable {
    services.earlyoom = {
      enable = true;

      # SIGTERM at 5% free memory (= 95% usage)
      freeMemThreshold = 5;
      # SIGKILL at 2% free memory (= 98% usage) if SIGTERM didn't work
      freeMemKillThreshold = 2;

      # swap thresholds
      freeSwapThreshold = 10;
      freeSwapKillThreshold = 5;

      # notifications handled by killHook below (avoids systembus-notify
      # conflict with smartd which sets it to false)
      enableNotifications = false;

      extraArgs = [
        # prefer killing known user memory hogs
        "--prefer"
        "(^|/)(Web Content|Isolated Web Co|firefox|chrome|chromium|electron|code|slack|discord|spotify|steam|java|node|deno|bun|Xwayland)$"

        # avoid killing system services and session infrastructure
        "--avoid"
        "(^|/)(init|systemd|sshd|seatd|dbus|pipewire|wireplumber|gdm|greetd|niri|sway|gnome-shell|mutter|polkit|tailscaled|NetworkManager|avahi|earlyoom)$"
      ];

      killHook = pkgs.writeShellScript "earlyoom-kill-notify" ''
        # log the kill
        echo "earlyoom killed: $EARLYOOM_NAME (PID $EARLYOOM_PID)" | ${pkgs.systemd}/bin/systemd-cat -t earlyoom-hook

        # send desktop notification as the primary user (in case systembus-notify missed it)
        PRIMARY_UID=$(${pkgs.coreutils}/bin/id -u daniel 2>/dev/null || echo "")
        if [ -n "$PRIMARY_UID" ]; then
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$PRIMARY_UID/bus" \
            ${pkgs.sudo}/bin/sudo -u daniel \
            ${pkgs.libnotify}/bin/notify-send \
              -u critical \
              -a "earlyoom" \
              "Process killed: $EARLYOOM_NAME" \
              "earlyoom killed $EARLYOOM_NAME (PID $EARLYOOM_PID) to prevent system lockup due to low memory." \
              2>/dev/null || true
        fi
      '';
    };
  };
}
