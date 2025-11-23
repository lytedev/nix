{ config, pkgs, ... }:
{
  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
  };

  services.caddy.virtualHosts."nix.h.lyte.dev" = {
    extraConfig = ''
      # Try bigtower first
      reverse_proxy bigtower.lan:5000 {
        header_up Host {upstream_hostport}

        # If bigtower returns 404 or connection error, try dragon
        @bigtower_miss status 404
        handle_response @bigtower_miss {
          reverse_proxy dragon.lan:5000 {
            header_up Host {upstream_hostport}

            # If dragon returns 404 or connection error, try beefcake (local)
            @dragon_miss status 404
            handle_response @dragon_miss {
              reverse_proxy :5000 {
                header_up Host {upstream_hostport}
              }
            }
          }
        }
      }
    '';
  };

  # regularly build this flake so we have stuff in the cache
  # TODO: schedule this for nightly builds instead of intervals based on boot time
  systemd.timers."build-lytedev-flake" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30m"; # 30 minutes after booting
      OnUnitActiveSec = "1d"; # every day afterwards
      Unit = "build-lytedev-flake.service";
    };
  };

  systemd.tmpfiles.settings = {
    "10-daniel-nightly-flake-build" = {
      "/home/daniel/.home/.cache/nightly-flake-builds" = {
        "d" = {
          mode = "0750";
          user = "daniel";
          group = "daniel";
        };
      };
    };
  };

  systemd.services."build-lytedev-flake" = {
    # TODO: might want to add root for the most recent results?
    script = ''
      flake="git+https://git.lyte.dev/lytedev/nix.git"
      # build self (main server) configuration
      nixos-rebuild build --flake "$flake#beefcake" --accept-flake-config
      # build desktop configuration
      nixos-rebuild build --flake "$flake#dragon" --accept-flake-config
      # build main laptop configuration
      nixos-rebuild build --flake "$flake#foxtrot" --accept-flake-config
      # ensure dev shell packages are built (and cached)
      nix develop "$flake" --build
    '';
    path = with pkgs; [
      openssh
      git
      nixos-rebuild
      nix
    ];
    serviceConfig = {
      # TODO: mkdir -p...?
      WorkingDirectory = "/home/daniel/.home/.cache/nightly-flake-builds";
      Type = "oneshot";
      User = "daniel";
    };
  };

  networking = {
    extraHosts = ''
      ::1 nix.h.lyte.dev
      127.0.0.1 nix.h.lyte.dev
    '';
  };
}
