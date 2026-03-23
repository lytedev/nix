{ config, ... }:

{
  # Create syncthing data directory
  systemd.tmpfiles.settings = {
    "10-syncthing" = {
      "/storage/syncthing" = {
        "d" = {
          mode = "0750";
          user = "syncthing";
          group = "syncthing";
        };
      };
    };
  };

  # Add syncthing data to backup paths
  services.restic.commonPaths = [
    "/storage/syncthing"
  ];

  # Enable syncthing service
  services.syncthing = {
    enable = true;
    user = "syncthing";
    group = "syncthing";
    dataDir = "/storage/syncthing";
    configDir = "/storage/syncthing/.config/syncthing";
    openDefaultPorts = false; # Don't open firewall ports by default

    # Web UI settings
    guiAddress = "127.0.0.1:8384";

    # You can configure devices and folders here, or manage them via the web UI
    settings = {
      options = {
        urAccepted = -1; # Disable usage reporting
      };
      gui = {
        user = "daniel";
        # Password should be set via the web UI on first login or via sops
        # This will prompt for password setup on first access
      };

      devices = {
        flab = {
          id = "GWQNBFC-JJW4N44-KICEWWU-UPCLY5Q-5TOTYCX-NDDP63K-EFF7RUU-P2PGWAX";
          autoAcceptFolders = true;
        };
        thinker = {
          id = "BRNARRJ-Q2FG42U-BO2YUM3-WGA2IUA-ZQDXTNC-4O5AVWC-G5RQRCI-6ZWLQQR";
          autoAcceptFolders = true;
        };
        dragon = {
          id = "ZXBA3C3-H2O3NVP-4THM4BE-G644ZUW-W4OWEMB-KUCMPOV-5SQBSQZ-JADSGQ2";
          autoAcceptFolders = true;
        };
        foxtrot = {
          id = "YMA4L72-CTVKNBM-IKNI77T-ERA2AJ2-HMA5PDU-WYM6ROR-7O7HVLC-54NRWA4";
          autoAcceptFolders = true;
        };
        babyflip = {
          id = "B2CSTI7-3JAPJF3-6LYPNUP-KKSNIAR-NUA2ZBX-R3LPB77-BYHEKGF-3BQI5QY";
          autoAcceptFolders = true;
        };
      };

      folders = {
        "notes" = {
          path = "/storage/daniel/notes";
          devices = [
            "flab"
            "thinker"
            "dragon"
            "foxtrot"
            "babyflip"
          ];
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        };
      };
    };
  };

  # Expose web UI via Caddy
  services.caddy.virtualHosts."syncthing.h.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :8384 {
        header_up Host 127.0.0.1:8384
      }
    '';
  };
}
