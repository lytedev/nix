{
  lib,
  options,
  config,
  pkgs,
  ...
}:
{
  options.lyte = {
    laptop = {
      enable = lib.mkEnableOption "Enable certain laptop-specific configuration options.";
    };
    two-in-one = {
      enable = lib.mkEnableOption "Enable two-in-one/convertible laptop configuration (implies laptop).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.lyte.two-in-one.enable {
      lyte.laptop.enable = true;
      hardware.sensor.iio.enable = true;
    })

    (lib.mkIf config.lyte.laptop.enable {
      lyte.desktop.enable = lib.mkDefault true;
      hardware.bluetooth.enable = lib.mkDefault true;
      networking.wifi.enable = lib.mkDefault true;
      services.libinput.touchpad = {
        naturalScrolling = true;
        disableWhileTyping = false;
        tapping = true;
      };

      environment.systemPackages = with pkgs; [
        acpi
      ];

      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
        ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      '';

      services.upower.enable = true;

      # Disable NMI watchdog at runtime (belt-and-suspenders with nowatchdog kernel param)
      boot.kernel.sysctl."kernel.nmi_watchdog" = 0;

      # Enable WiFi powersave
      networking.networkmanager.wifi.powersave = true;

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
    })
  ];
}
