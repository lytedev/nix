{...}: {
  # TODO: would like to move away from network manager to iwd
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # TODO: powersave?

  # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
}
