# Shared Syncthing module for desktop hosts
#
# Syncs common directories (wallpapers, etc.) across machines.
# Pre-generated device IDs allow instant mutual discovery.
# Private keys are deployed via sops-nix secrets per-host.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.syncthing;
  danielHome = config.users.users.daniel.home;

  # Pre-generated device IDs (from TLS certs in secrets/syncthing/)
  allDeviceIDs = {
    flab = "GWQNBFC-JJW4N44-KICEWWU-UPCLY5Q-5TOTYCX-NDDP63K-EFF7RUU-P2PGWAX";
    thinker = "BRNARRJ-Q2FG42U-BO2YUM3-WGA2IUA-ZQDXTNC-4O5AVWC-G5RQRCI-6ZWLQQR";
    dragon = "ZXBA3C3-H2O3NVP-4THM4BE-G644ZUW-W4OWEMB-KUCMPOV-5SQBSQZ-JADSGQ2";
    foxtrot = "YMA4L72-CTVKNBM-IKNI77T-ERA2AJ2-HMA5PDU-WYM6ROR-7O7HVLC-54NRWA4";
    babyflip = "B2CSTI7-3JAPJF3-6LYPNUP-KKSNIAR-NUA2ZBX-R3LPB77-BYHEKGF-3BQI5QY";
    beefcake = "PLMVASI-ORAHWVB-44B4ZTS-42NNKNE-UOF57CQ-FQUYM4O-DFEKNIR-Y3VYQQN";
  };

  # All device names except this host
  otherDevices = lib.filter (d: d != config.networking.hostName) (lib.attrNames cfg.devices);
in
{
  options.lyte.syncthing = {
    enable = lib.mkEnableOption "Syncthing file sync for desktop hosts";

    devices = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = allDeviceIDs;
      description = "Mapping of hostname to Syncthing device ID (defaults to pre-generated IDs)";
    };

    folders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        wallpapers = "${danielHome}/Sync/wallpapers";
        shared = "${danielHome}/Sync/shared";
        notes = "${danielHome}/Documents/notes";
      };
      description = "Mapping of folder label to local path";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "daniel";
      group = "users";
      dataDir = "${danielHome}/Sync";
      configDir = "${danielHome}/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;

      settings = {
        options = {
          urAccepted = -1;
        };

        devices = lib.mapAttrs (name: id: {
          inherit id name;
          autoAcceptFolders = true;
        }) cfg.devices;

        folders = lib.mapAttrs (label: path: {
          inherit path;
          devices = otherDevices;
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        }) cfg.folders;
      };
    };

    # Syncthing Tray plasmoid for KDE Plasma system tray.
    # The plasmoid integrates natively with Plasma's system tray and uses
    # systemd to monitor the syncthing service (no built-in launcher needed).
    # See: https://github.com/Martchus/syncthingtray#configuring-plasmoid
    environment.systemPackages = lib.mkIf config.lyte.desktop.plasma.enable [
      pkgs.syncthingtray
    ];
  };
}
