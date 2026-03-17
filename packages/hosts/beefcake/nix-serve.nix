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

  # regularly build this flake with updated inputs to keep the cache warm
  systemd.timers."build-lytedev-flake" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00"; # 3am daily
      Persistent = true; # run if missed (e.g., machine was off)
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
    script = ''
      set -euo pipefail
      repo_url="https://git.lyte.dev/lytedev/nix.git"
      repo_dir="/home/daniel/.home/.cache/nightly-flake-builds/nix"

      # clone or update the local checkout
      if [ -d "$repo_dir/.git" ]; then
        git -C "$repo_dir" fetch --all
        git -C "$repo_dir" reset --hard origin/main
      else
        git clone "$repo_url" "$repo_dir"
      fi

      cd "$repo_dir"

      # update flake inputs to latest
      nix flake update --accept-flake-config

      # build configurations (populates cache)
      # failures are expected since we build against latest nixpkgs
      nixos-rebuild build --flake ".#beefcake" --accept-flake-config || true
      nixos-rebuild build --flake ".#dragon" --accept-flake-config || true
      nixos-rebuild build --flake ".#foxtrot" --accept-flake-config || true
      # nixos-rebuild build --flake ".#pinephone" --accept-flake-config # temporarily disabled

      # ensure dev shell packages are built (and cached)
      nix develop . --build || true
    '';
    path = with pkgs; [
      openssh
      git
      nixos-rebuild
      nix
    ];
    serviceConfig = {
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
