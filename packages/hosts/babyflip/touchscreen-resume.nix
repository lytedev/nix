{ pkgs, ... }:
{
  # Fix ELAN touchscreen not working after resume from suspend
  systemd.services.fix-touchscreen-resume = {
    description = "Rebind ELAN touchscreen after resume";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo i2c-ELAN901C:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind; sleep 0.5; echo i2c-ELAN901C:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind'";
    };
  };
}
