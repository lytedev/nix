{
  diskoConfigurations,
  # hardware, # do NOT use nixos-hardware with jovian config
  ...
}:
{
  system.stateVersion = "24.11";

  networking = {
    hostName = "steamdeckoled";
    wifi.enable = true;
  };

  imports = [
    (diskoConfigurations.unencrypted { disk = "/dev/nvme0n1"; })
  ];

  lyte.steamdeck.enable = true;
}
