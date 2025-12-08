{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.lyte.steamdeck = {
    enable = lib.mkEnableOption "Steam Deck configuration";
  };

  config = lib.mkIf config.lyte.steamdeck.enable {
    hardware.bluetooth.enable = true;
    boot = {
      # kernelPackages = pkgs.linuxPackages_latest; # do NOT use with jovian config
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };
    };

    lyte.desktop.enable = true;
    lyte.shell.enable = true;

    environment.systemPackages = with pkgs; [
      steamdeck-firmware
      steam-rom-manager
    ];

    services.flatpak.enable = true;
    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "tailscaled.service" ];
      path = with pkgs; [ flatpak ];
      script = ''
        for delay in 1 2 4 8 15 30; do
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && exit 0
          echo "Failed, retrying in ''${delay}s..."
          sleep $delay
        done
        echo "Giving up after multiple attempts"
        exit 1
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    services.displayManager.gdm.enable = lib.mkForce false;

    home-manager.users.daniel = {
      lyte = {
        useOutOfStoreSymlinks.enable = true;
        shell = {
          enable = true;
          learn-jujutsu-not-git.enable = true;
        };
        desktop.enable = true;
      };
      # TODO: syncthing for daniel user on steamdecks for rom syncing?
    };

    nixpkgs.config.allowUnfree = true;
    programs.steam.enable = true;

    # Enable nix-ld for running unpatched binaries
    programs.nix-ld.enable = true;

    jovian = {
      decky-loader = {
        enable = true;
      };
      steam = {
        enable = true;
        autoStart = true;
        desktopSession = "gnome";
        user = "daniel";
        updater = {
          splash = "jovian";
        };
      };
      hardware = {
        has.amd.gpu = true;
      };
      devices = {
        steamdeck = {
          enable = true;
          autoUpdate = true;
          enableGyroDsuService = true;
        };
      };
    };
  };
}
