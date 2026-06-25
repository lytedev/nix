{ config, lib, ... }:
let
  # Reuse device IDs from the shared syncthing module
  deviceIDs = config.lyte.syncthing.devices;
  otherDevices = lib.attrNames (builtins.removeAttrs deviceIDs [ "beefcake" ]);
in
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

  # Intentionally NOT backed up via restic. Syncthing is its own backup layer:
  # data is replicated across peer devices, and versioning is configured per
  # folder below. Including it in restic would double-store large, churn-heavy
  # data and risk capturing the live index DB mid-write.

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

      devices = lib.mapAttrs (_: id: {
        inherit id;
        autoAcceptFolders = true;
      }) (builtins.removeAttrs deviceIDs [ "beefcake" ]);

      folders = {
        "notes" = {
          path = "/storage/syncthing/daniel/notes";
          devices = otherDevices;
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        };
        # RetroDECK ROM/save hub. ROMs and saves are separate folders (saves are
        # small/high-churn/irreplaceable and shouldn't wait behind a multi-GB ROM
        # rescan). Shared only with the hosts that actually hold a RetroDECK tree.
        # NOTE: replaces the old ad-hoc whole-dir "retrodeck" web-UI folder, which
        # must be removed from the live config first (a folder can't be nested
        # inside another syncthing folder).
        "retrodeck-roms" = {
          path = "/storage/syncthing/retrodeck/roms";
          devices = [
            "dragon"
            "steamdeck"
            "steamdeckoled"
          ];
        };
        "retrodeck-saves" = {
          path = "/storage/syncthing/retrodeck/saves";
          devices = [
            "dragon"
            "steamdeck"
            "steamdeckoled"
          ];
          versioning = {
            type = "simple";
            params.keep = "10";
          };
        };
      };
    };
  };

  # syncthing-init is a oneshot that pushes the declarative settings into the
  # running syncthing instance. If syncthing.service restarts mid-run (e.g.
  # during a NixOS rebuild), the init is SIGTERM'd and, with no Restart=,
  # stays failed until someone resets it — leaving the OpenObserve
  # systemd_unit_failed alert ringing indefinitely. Retry on failure so a
  # transient restart self-heals.
  systemd.services.syncthing-init.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "30s";
  };

  # Web UI is intentionally NOT exposed on the public internet and not reverse-
  # proxied. The GUI binds to 127.0.0.1:8384 (see guiAddress above); reach it
  # over the tailnet via SSH local-forward, picking a free local port (clients
  # usually already have their own Syncthing on 8384), e.g.
  #   ssh -L 18384:127.0.0.1:8384 root@beefcake.internal.vpn.h.lyte.dev
  # then browse to http://127.0.0.1:18384.
}
