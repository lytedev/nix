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

    services.logind =
      {
      }
      // (
        let
          logindSettings = {
            "KillUserProcesses" = false;

            "HandlePowerKey" = "suspend-then-hibernate";
            "HandlePowerKeyLongPress" = "poweroff";

            "HandleRebootKey" = "reboot";
            "HandleRebootKeyLongPress" = "poweroff";

            "HandleSuspendKey" = "suspend-then-hibernate";
            "HandleSuspendKeyLongPress" = "hibernate";

            "HandleHibernateKey" = "hibernate";
            "HandleHibernateKeyLongPress" = "ignore";

            "HandleLidSwitch" = "suspend-then-hibernate";
            "HandleLidSwitchExternalPower" = "suspend";
            "HandleLidSwitchDocked" = "suspend";

            "IdleActionSec" = "11m";
            "IdleAction" = "hibernate";
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
