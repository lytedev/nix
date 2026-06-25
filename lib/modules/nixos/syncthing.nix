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
  danielHome = config.lyte.userHome;

  # Pre-generated device IDs (from TLS certs in secrets/syncthing/)
  allDeviceIDs = {
    flab = "GWQNBFC-JJW4N44-KICEWWU-UPCLY5Q-5TOTYCX-NDDP63K-EFF7RUU-P2PGWAX";
    thinker = "BRNARRJ-Q2FG42U-BO2YUM3-WGA2IUA-ZQDXTNC-4O5AVWC-G5RQRCI-6ZWLQQR";
    dragon = "ZXBA3C3-H2O3NVP-4THM4BE-G644ZUW-W4OWEMB-KUCMPOV-5SQBSQZ-JADSGQ2";
    foxtrot = "YMA4L72-CTVKNBM-IKNI77T-ERA2AJ2-HMA5PDU-WYM6ROR-7O7HVLC-54NRWA4";
    babyflip = "B2CSTI7-3JAPJF3-6LYPNUP-KKSNIAR-NUA2ZBX-R3LPB77-BYHEKGF-3BQI5QY";
    beefcake = "CLIA25Z-SODKDAJ-TOXKZKF-D3SXEHI-NWCXONN-77FE67Y-C6KGU7I-P43JVQ3";
    phone = "MPNOYAO-NRKQWTY-TE5JTYN-BY7OUX6-MF5RFD3-BCIIBH7-5Q7V6FZ-YI2TQQF";
    steamdeck = "XXLQLKT-NJ5BZKA-JV6PC5P-LUKHZMA-54BS3N3-FJ2UWR2-KFY6C7I-MFCWAAX";
    steamdeckoled = "PKQEPCI-3UB4NHA-7Z6RZ7L-VFGX7TF-KLT73MB-TTA6ZBO-R4UA5PP-MZTAVQF";
  };

  # Mobile-only devices: included only in the notes folder, not wallpapers/shared
  mobileDevices = [ "phone" ];

  # All device names except this host
  otherDevices = lib.filter (d: d != config.networking.hostName) (lib.attrNames cfg.devices);
in
{
  options.lyte.syncthing = {
    enable = lib.mkEnableOption "Syncthing file sync for desktop hosts";

    guiPasswordSopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../secrets/workstations/syncthing.yml;
      description = ''
        sops file providing the `syncthing-gui-password` secret. Defaults to the
        shared workstations secret; hosts that are not workstation-secret
        recipients (e.g. the Steam Decks) override this with their own per-host
        secret so they don't need access to unrelated workstation secrets.
      '';
    };

    devices = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = allDeviceIDs;
      description = "Mapping of hostname to Syncthing device ID (defaults to pre-generated IDs)";
    };

    folders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        wallpapers = "${danielHome}/Pictures/Wallpapers";
        shared = "${danielHome}/Sync/shared";
        notes = "${danielHome}/Documents/notes";
      };
      description = "Mapping of folder label to local path";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.syncthing-gui-password = {
      sopsFile = cfg.guiPasswordSopsFile;
      mode = "0440";
      owner = "daniel";
      group = "users";
    };

    services.syncthing = {
      enable = true;
      user = "daniel";
      group = "users";
      dataDir = "${danielHome}/Sync";
      configDir = "${danielHome}/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        gui = {
          user = "daniel";
          # Password is set at runtime via systemd service below
        };

        options = {
          urAccepted = -1;
        };

        # Prefer Tailscale (MagicDNS FQDN) so client-isolated networks don't
        # block sync; "dynamic" stays as a fallback for when DNS can't resolve.
        devices = lib.mapAttrs (name: id: {
          inherit id name;
          autoAcceptFolders = false;
          addresses = [
            "tcp://${name}.internal.vpn.h.lyte.dev:22000"
            "dynamic"
          ];
        }) cfg.devices;

        folders = lib.mapAttrs (label: path: {
          inherit path;
          devices =
            if label == "notes" then
              otherDevices
            else
              lib.filter (d: !(builtins.elem d mobileDevices)) otherDevices;
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        }) cfg.folders;
      };
    };

    # Set the GUI password from sops secret after syncthing starts
    systemd.services.syncthing-set-gui-password = {
      description = "Set Syncthing GUI password from sops secret";
      after = [ "syncthing.service" ];
      requires = [ "syncthing.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.syncthing ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "daniel";
        Group = "users";
        Environment = "STNODEFAULTFOLDER=1";
      };
      script = ''
        export STHOMEDIR="${danielHome}/.config/syncthing"
        PASSWORD="$(cat ${config.sops.secrets.syncthing-gui-password.path})"
        # Wait for syncthing API to be ready
        for i in $(seq 1 30); do
          if syncthing cli config gui get 2>/dev/null | grep -q user; then
            break
          fi
          sleep 2
        done
        syncthing cli config gui password set "$PASSWORD"
      '';
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
