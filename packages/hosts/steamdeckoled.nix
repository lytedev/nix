{ config, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "steamdeckoled";

  diskConfig = {
    name = "unencrypted";
    params.disk = "/dev/nvme0n1";
  };

  lyte.steamdeck.enable = true;

  # Syncthing: sync the RetroDECK ROM and save collection with the beefcake
  # hub (and dragon). ROMs and saves are kept as two separate folders so the
  # small, high-churn, irreplaceable saves propagate immediately instead of
  # waiting behind a multi-GB ROM rescan. The whole ~/retrodeck dir is
  # deliberately NOT synced (its ES-DE caches/logs/per-device config caused
  # cross-device conflicts in the past).
  lyte.syncthing = {
    enable = true;
    # Decks are not workstation-secret recipients; use the per-host secret.
    guiPasswordSopsFile = ../../secrets/steamdeckoled/secrets.yml;
    folders = {
      retrodeck-roms = "${config.lyte.userHome}/retrodeck/roms";
      retrodeck-saves = "${config.lyte.userHome}/retrodeck/saves";
    };
  };

  services.syncthing = {
    cert = config.sops.secrets.syncthing-cert.path;
    key = config.sops.secrets.syncthing-key.path;
  };

  sops.secrets =
    let
      syncthingSecret = {
        sopsFile = ../../secrets/steamdeckoled/secrets.yml;
        mode = "0400";
        owner = "daniel";
        group = "users";
      };
    in
    {
      syncthing-key = syncthingSecret;
      syncthing-cert = syncthingSecret;
    };
}
