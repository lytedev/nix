{lib, ...}: {
  networking.networkmanager.enable = lib.mkDefault true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkDefault false;
  # TODO: networking.networkmanager.wifi.backend = "iwd"; ?

  # TODO: powersave?

  # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
}
