{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.lyte.laptop.enable {
    environment.systemPackages = with pkgs; [
      acpi
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    '';

    services.upower.enable = true;

    # NOTE: I previously let plasma settings handle this
    services.logind = {
      lidSwitch = "suspend-then-hibernate";
      extraConfig = ''
        KillUserProcesses=no
        HandlePowerKey=suspend
        HandlePowerKeyLongPress=poweroff
        HandleRebootKey=reboot
        HandleRebootKeyLongPress=poweroff
        HandleSuspendKey=suspend
        HandleSuspendKeyLongPress=hibernate
        HandleHibernateKey=hibernate
        HandleHibernateKeyLongPress=ignore
        HandleLidSwitch=suspend
        HandleLidSwitchExternalPower=suspend
        HandleLidSwitchDocked=suspend
        HandleLidSwitchDocked=suspend
        IdleActionSec=11m
        IdleAction=ignore
      '';
    };
  };
}
