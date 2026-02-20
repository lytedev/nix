{ config, pkgs, ... }:
{
  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
  };

  services.caddy.virtualHosts."nix.h.lyte.dev" = {
    extraConfig = ''
      # Binary cache cascade: dragon (fast SSDs) → localhost (CI builds) → bigtower
      # Each level falls through on cache miss (404) or backend down (502)
      reverse_proxy dragon.lan:5000 {
        transport http {
          dial_timeout 2s
        }
        @miss status 404 502
        handle_response @miss {
          reverse_proxy localhost:5000 {
            @miss status 404 502
            handle_response @miss {
              reverse_proxy bigtower.lan:5000
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
      # build pinephone configuration (aarch64, uses binfmt)
      nixos-rebuild build --flake "$flake#pinephone" --accept-flake-config
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
