{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkDefault;
  cfg = config.networking.wifi;
in
{
  options = {
    networking.wifi.enable = lib.mkEnableOption "Enable wifi via NetworkManager";
  };
  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;
      # ensureProfiles = {
      #   profiles = {
      #     home-wifi = {
      #     id="home-wifi";
      #     permissions = "";
      #     type = "wifi";
      #     };
      #     wifi = {
      #     ssid = "";
      #     };
      #     wifi-security = {
      #     # auth-alg = "";
      #     # key-mgmt = "";
      #     psk = "";
      #     };
      #   };
      # };
    };
    systemd.services.NetworkManager-wait-online.enable = mkDefault false;

    /*
      TODO: networking.networkmanager.wifi.backend = "iwd"; ?
      TODO: powersave?
      TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
    */
    hardware.wirelessRegulatoryDatabase = true;
    boot.extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom="US"
    '';
  };
}
