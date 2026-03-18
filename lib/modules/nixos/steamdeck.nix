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

        environment.systemPackages = with pkgs; [
          steamdeck-firmware
          steam-rom-manager
          shipwright # Ship of Harkinian — OoT PC port
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

      # Jovian's autostart module enables SDDM for session management (including
      # "Switch to Desktop"). Disable plasma-login-manager if present so it
      # doesn't conflict with SDDM.
      (
        if (options.services.displayManager ? plasma-login-manager) then
          {
            services.displayManager.plasma-login-manager.enable = lib.mkForce false;
          }
        else
          { }
      )

      # Fix "Switch to Desktop" session switching.
      #
      # steamos-manager writes a temporary SDDM config to
      # /etc/sddm.conf.d/zzt-steamos-temp-login.conf to override the autologin
      # session (e.g. from gamescope to plasma). Two things prevent this from
      # working out of the box:
      #
      # 1. Config precedence: the NixOS SDDM module bakes
      #    [Autologin] Session=gamescope-wayland.desktop into /etc/sddm.conf,
      #    which is loaded *after* sddm.conf.d/ and overrides the temp file.
      #    Fix: disable NixOS autoLogin so that section is omitted from
      #    sddm.conf, and put the autologin config in a conf.d drop-in
      #    (00-autologin.conf) that sorts before the zzt- temp file.
      #
      # 2. ExecStartPre cleanup: Jovian's autostart module adds an ExecStartPre
      #    that deletes the temp file before SDDM starts, so it never gets
      #    read on restart. Fix: clear the ExecStartPre list. The temp file
      #    is already cleaned up by steamos-manager-session-cleanup.service
      #    after the session starts.
      {
        # Prevent [Autologin] from appearing in /etc/sddm.conf so conf.d
        # files can control the session without being overridden.
        services.displayManager.autoLogin.enable = lib.mkForce false;

        # Provide the default autologin via a conf.d drop-in instead.
        # 00- prefix ensures it sorts before zz-steamos-autologin.conf and
        # zzt-steamos-temp-login.conf, so steamos-manager can override it.
        environment.etc."sddm.conf.d/00-autologin.conf".text = ''
          [Autologin]
          User=${config.jovian.steam.user}
          Session=gamescope-wayland.desktop
          Relogin=true
        '';

        # Remove Jovian's ExecStartPre that deletes the temp session file.
        # Without this, the temp file written by steamos-manager for
        # "Switch to Desktop" would be deleted before SDDM can read it.
        # Note: this also clears the NixOS preStart "rm -f /tmp/.X0-lock"
        # (harmless — only relevant for X11 sessions, not Wayland SDDM).
        # Both preStart and Jovian's ExecStartPre feed into the same
        # serviceConfig.ExecStartPre list, so we must force both empty.
        systemd.services.display-manager.preStart = lib.mkForce "";
        systemd.services.display-manager.serviceConfig.ExecStartPre = lib.mkForce [ ];
      }
    ]
  );
}
