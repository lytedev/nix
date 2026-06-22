{ pkgs, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "steamdeckoled";

  diskConfig = {
    name = "unencrypted";
    params.disk = "/dev/nvme0n1";
  };

  lyte.steamdeck.enable = true;

  # Power/status LED ("status:white", brightness 0-100) is root-only writable
  # by default, so it can't be adjusted without sudo. Hand the brightness file
  # to the `wheel` group on device-add so daniel can set it directly:
  #   echo <0-100> > /sys/class/leds/status:white/brightness
  # (sysfs brightness resets on reboot; ask if you want a persistent default.)
  services.udev.extraRules = ''
    SUBSYSTEM=="leds", KERNEL=="status:white", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp wheel /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/%k/brightness"
  '';
}
