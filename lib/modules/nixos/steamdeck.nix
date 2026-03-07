{
  lib,
  config,
  options,
  pkgs,
  ...
}:
{
  options.lyte.steamdeck = {
    enable = lib.mkEnableOption "Steam Deck configuration";
  };

  config = lib.mkIf config.lyte.steamdeck.enable (
    lib.mkMerge [
      {
        hardware.bluetooth.enable = true;
        networking.wifi.enable = lib.mkDefault true;
        lyte.headscale.usePreAuthKey = lib.mkDefault true;
        boot = {
          # kernelPackages = pkgs.linuxPackages_latest; # do NOT use with jovian config
          loader = {
            efi.canTouchEfiVariables = true;
            systemd-boot.enable = true;
          };
        };

        lyte.shell.enable = true;
        lyte.desktop.enable = true;

        # Jovian manages the session (autologin to Steam), so disable the display manager
        services.displayManager.sddm.enable = lib.mkForce false;

        environment.systemPackages = with pkgs; [
          steamdeck-firmware
          steam-rom-manager
        ];

        # flatpak is already enabled by lyte.desktop, but the repo service is steamdeck-specific
        systemd.services.flatpak-repo = {
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
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

        # TODO: syncthing for daniel user on steamdecks for rom syncing?

        nixpkgs.config.allowUnfree = true;
        programs.steam.enable = true;

        # Enable nix-ld for running unpatched binaries
        programs.nix-ld.enable = true;

        jovian = {
          decky-loader = {
            enable = true;
            user = "daniel";
          };
          steam = {
            enable = true;
            autoStart = true;
            desktopSession = "plasma";
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
      }

      (
        if (options.services.displayManager ? plasma-login-manager) then
          {
            services.displayManager.plasma-login-manager.enable = lib.mkForce false;
          }
        else
          { }
      )
    ]
  );
}
