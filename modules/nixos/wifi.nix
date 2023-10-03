{...}: {
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # iwd?
  # powersave?
  # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded
  # from secrets?
}
