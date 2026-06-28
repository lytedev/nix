{ config, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "steamdeck";

  diskConfig = {
    name = "unencrypted";
    params.disk = "/dev/nvme0n1";
  };

  lyte.steamdeck.enable = true;

  # Living-room TV audio: a squeezelite player that Music Assistant streams to
  # (MA's squeezelite/SlimProto provider on bigtower). Shows up in MA as the
  # "Living Room" player for "play X in the living room" + group playback.
  lyte.squeezelite = {
    enable = true;
    name = "Living Room";
  };

  # Video on the TV: a small control service that launches mpv fullscreen into
  # the desktop session when Home Assistant says "play X on the TV" (over the
  # Firefox/Hearth kiosk; quitting mpv returns to it). YouTube via yt-dlp.
  lyte.tv-player = {
    enable = true;
    tokenFile = config.sops.secrets.tv-control-token.path;
  };

  # Syncthing: sync the RetroDECK ROM and save collection with the beefcake
  # hub (and dragon). ROMs and saves are kept as two separate folders so the
  # small, high-churn, irreplaceable saves propagate immediately instead of
  # waiting behind a multi-GB ROM rescan. The whole ~/retrodeck dir is
  # deliberately NOT synced (its ES-DE caches/logs/per-device config caused
  # cross-device conflicts in the past).
  lyte.syncthing = {
    enable = true;
    # Decks are not workstation-secret recipients; use the per-host secret.
    guiPasswordSopsFile = ../../secrets/steamdeck/secrets.yml;
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
        sopsFile = ../../secrets/steamdeck/secrets.yml;
        mode = "0400";
        owner = "daniel";
        group = "users";
      };
    in
    {
      syncthing-key = syncthingSecret;
      syncthing-cert = syncthingSecret;
      # Bearer token for the tv-player control service (root-owned; the service
      # runs as root to launch mpv into daniel's session).
      tv-control-token.sopsFile = ../../secrets/steamdeck/secrets.yml;
    };
}
