{
  lib,
  options,
  config,
  pkgs,
  ...
}:
{
  options.lyte.laptop = {
    enable = lib.mkEnableOption "Enable certain laptop-specific configuration options.";
  };

  config = lib.mkIf config.lyte.laptop.enable {
    home-manager.users.daniel.dconf.settings = {
      "org/gnome/desktop/peripherals/touchpad" = {
        disable-while-typing = false;
        natural-scroll = true;
        # accel-profile = "adaptive";
        # speed = 0.5;
      };
    };

    environment.etc."niri/laptop.kdl".text = ''
      input {
        touchpad {
          tap
          dwt
          natural-scroll
          accel-speed 0.5
          accel-profile "adaptive"
        }
      }
    '';

    environment.systemPackages = with pkgs; [
      acpi
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    '';

    services.upower.enable = true;

    # TODO: s3/deep mem_sleep option for /sys/power/mem_sleep if available?

    systemd.sleep.extraConfig = "HibernateDelaySec=11m";

    services.logind = {
    }
    // (
      let
        logindSettings = {
          "KillUserProcesses" = false;

          "HandlePowerKey" = "suspend";
          "HandlePowerKeyLongPress" = "poweroff";

          "HandleRebootKey" = "reboot";
          "HandleRebootKeyLongPress" = "poweroff";

          "HandleSuspendKey" = "suspend";
          "HandleSuspendKeyLongPress" = "hibernate";

          "HandleHibernateKey" = "hibernate";
          "HandleHibernateKeyLongPress" = "hibernate";

          "HandleLidSwitch" = "suspend";
          "HandleLidSwitchExternalPower" = "suspend";
          "HandleLidSwitchDocked" = "suspend";

          # Respect sleep inhibitors for lid switch events (default is yes/ignore)
          # "LidSwitchIgnoreInhibited" = false; # this must be disastrous; if I close the laptop in any situation, I definitely want it to sleep and not melt itself

          "IdleActionSec" = "11m";
          "IdleAction" = "suspend";
        };
      in
      if builtins.hasAttr "settings" options.services.logind then
        {
          settings.Login = logindSettings;
        }
      else
        {
          extraConfig =
            let
              toValueString = val: if builtins.isBool val then if val then "yes" else "no" else val;
            in
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: value: "${name}=${toValueString value}") logindSettings
            );
        }
    );
  };
}
