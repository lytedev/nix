{
  system.stateVersion = "24.11";
  networking.hostName = "steamdeck";

  diskConfig = {
    name = "unencrypted";
    params.disk = "/dev/nvme0n1";
  };

  lyte.steamdeck.enable = true;
}
