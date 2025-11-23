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
