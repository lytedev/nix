{ ... }: {
  networking.networkmanager.enable = true;

  # iwd?
  # powersave?
  # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded
  # from secrets?
}
