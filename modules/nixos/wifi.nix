{lib, ...}: let
  inherit (lib) mkDefault;
in {
  networking.networkmanager.enable = mkDefault true;
  systemd.services.NetworkManager-wait-online.enable = mkDefault false;

  # TODO: networking.networkmanager.wifi.backend = "iwd"; ?
  # TODO: powersave?
  # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
}
