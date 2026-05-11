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

      # Disable wakeup sources and unload flaky WiFi module before hibernate
      # to prevent "wakeup event detected during hibernation, rolling back"
      # and mt7921e firmware timeout errors
      systemd.services.hibernate-prep = {
        description = "Prepare system for hibernation";
        before = [
          "hibernate.target"
          "suspend-then-hibernate.target"
        ];
        wantedBy = [
          "hibernate.target"
          "suspend-then-hibernate.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "hibernate-prep" ''
            export PATH="${
              lib.makeBinPath [
                pkgs.kmod
                pkgs.gnugrep
                pkgs.coreutils
              ]
            }:$PATH"

            # Disable USB/Thunderbolt wakeup sources that cause spurious wakeups
            for src in XHC0 XHC1 XHC3 XHC4 NHI0 NHI1; do
              if grep -q "$src.*enabled" /proc/acpi/wakeup; then
                echo "$src" > /proc/acpi/wakeup
              fi
            done

            # Unload mt7921e WiFi — its firmware times out during hibernate
            if lsmod | grep -q mt7921e; then
              modprobe -r mt7921e 2>/dev/null || true
            fi
          '';
        };
      };

      systemd.services.hibernate-resume = {
        description = "Restore system after hibernation";
        after = [
          "hibernate.target"
          "suspend-then-hibernate.target"
        ];
        wantedBy = [
          "hibernate.target"
          "suspend-then-hibernate.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "hibernate-resume" ''
            export PATH="${
              lib.makeBinPath [
                pkgs.kmod
                pkgs.gnugrep
                pkgs.coreutils
              ]
            }:$PATH"

            # Re-enable wakeup sources
            for src in XHC0 XHC1 XHC3 XHC4 NHI0 NHI1; do
              if grep -q "$src.*disabled" /proc/acpi/wakeup; then
                echo "$src" > /proc/acpi/wakeup
              fi
            done

            # Reload WiFi module
            modprobe mt7921e 2>/dev/null || true
          '';
        };
      };

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

            "HandleLidSwitch" = "suspend-then-hibernate";
            "HandleLidSwitchExternalPower" = "suspend-then-hibernate";
            "HandleLidSwitchDocked" = "suspend-then-hibernate";

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

    # HibernateDelaySec — use new settings path if available, old extraConfig otherwise
    (lib.mkIf config.lyte.laptop.enable (
      if options.systemd.sleep ? settings then
        { systemd.sleep.settings.Sleep.HibernateDelaySec = "11m"; }
      else
        { systemd.sleep.extraConfig = "HibernateDelaySec=11m"; }
    ))
  ];
}
