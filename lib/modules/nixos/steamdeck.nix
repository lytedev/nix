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
      (
        let
          # Steam's OOBE calls /usr/bin/steamos-polkit-helpers/steamos-update at a
          # hardcoded path, and calls jupiter-initial-firmware-update check via polkit.
          # On Jovian NixOS neither of these works out of the box:
          #   1. The sentinel /etc/jupiter-ran-initial-firmware-update doesn't exist,
          #      so jupiter-initial-firmware-update tries pkexec (no agent → exit 127)
          #      and Steam shows a "Day one firmware update" OOBE screen that can't
          #      complete.
          #   2. /usr/bin/steamos-polkit-helpers/ doesn't exist; the path was renamed
          #      to holo-polkit-helpers in newer Jovian but Steam still uses the old
          #      name.  Missing path → exit 127 → update checks always fail.
          #
          # Fix: persist the sentinel (firmware updates are handled by Nix derivations,
          # not by the SteamOS day-1 flow), and provide a compat helper directory that
          # calls the jovian stubs directly, bypassing pkexec.
          # Stubs for the host /usr/bin/steamos-polkit-helpers/ tmpfiles symlink.
          # Files are directly in $out/ (no bin/ subdir) because the tmpfiles
          # rule points /usr/bin/steamos-polkit-helpers → $out directly.
          steamosPolkitHelpersCompat = pkgs.runCommand "steamos-polkit-helpers-compat" { } ''
            mkdir -p $out
            for stub in steamos-update steamos-select-branch; do
              # Jovian (2026-06) renamed the top-level steamos-update stub to
              # holo-update; keep the Steam-facing name but exec the new one.
              case "$stub" in
                steamos-update) src=holo-update ;;
                *) src="$stub" ;;
              esac
              echo '#!/bin/sh' > $out/$stub
              echo "exec ${pkgs.jovian-stubs}/bin/$src \"\$@\"" >> $out/$stub
              chmod +x $out/$stub
            done
            printf '#!/bin/sh\nexit 0\n' > $out/jupiter-biosupdate
            chmod +x $out/jupiter-biosupdate
          '';

          # Package for the Steam FHS environment.  buildFHSEnv maps $out/bin/*
          # → /usr/bin/* inside the container, so files here appear at
          # /usr/bin/steamos-polkit-helpers/steamos-update inside the FHS rootfs
          # (which pressure-vessel then uses as the container's /usr/bin/).
          steamosPolkitHelpersFHS = pkgs.runCommand "steamos-polkit-helpers-fhs" { } ''
            mkdir -p $out/bin/steamos-polkit-helpers
            for stub in steamos-update steamos-select-branch; do
              # steamos-update was renamed to holo-update in Jovian (2026-06).
              case "$stub" in
                steamos-update) src=holo-update ;;
                *) src="$stub" ;;
              esac
              echo '#!/bin/sh' > $out/bin/steamos-polkit-helpers/$stub
              echo "exec ${pkgs.jovian-stubs}/bin/$src \"\$@\"" >> $out/bin/steamos-polkit-helpers/$stub
              chmod +x $out/bin/steamos-polkit-helpers/$stub
            done
            printf '#!/bin/sh\nexit 0\n' > $out/bin/steamos-polkit-helpers/jupiter-biosupdate
            chmod +x $out/bin/steamos-polkit-helpers/jupiter-biosupdate
          '';

          # jupiter-initial-firmware-update normally calls pkexec to become root
          # before checking the sentinel.  On Jovian NixOS there is no polkit
          # agent in the gamescope session, so pkexec returns 127 and Steam's
          # OOBE shows a "Day one firmware update" screen that cannot complete.
          # This wrapper checks the sentinel first (no root needed for a file
          # existence check) and short-circuits before touching pkexec.
          jupiterInitialFirmwareUpdateCompat = lib.hiPrio (
            pkgs.writeShellScriptBin "jupiter-initial-firmware-update" ''
              # The sentinel is in /run/ (not /etc/) so it is visible inside the
              # steam-runtime pressure-vessel container, which mounts its own /etc/
              # but shares /run/ with the host.
              SENTINEL=/run/jovian/jupiter-ran-initial-firmware-update
              case "$1" in
                check)
                  if [ -e "$SENTINEL" ]; then
                    exit 0
                  fi
                  ;;
              esac
              exec ${pkgs.steamdeck-firmware}/bin/jupiter-initial-firmware-update "$@"
            ''
          );
        in
        {
          # Prevent the Steam "Day one firmware update" OOBE from blocking setup.
          # On Jovian NixOS firmware is managed via Nix, not the SteamOS update flow.
          # Put the sentinel under /run/jovian/ — the steam-runtime container mounts
          # its own /etc/ but shares /run/ with the host, so /etc/ is not visible
          # inside the container but /run/ is.
          # High-priority wrapper that short-circuits the sentinel check before pkexec.
          # Also add steamos-update and steamos-update-rauc stubs to system packages
          # so they land in /run/current-system/sw/bin/, which is bind-mounted into
          # the steam-runtime container and will be found even when SYSTEM_PATH is
          # not explicitly passed to subprocesses.
          environment.systemPackages = [
            jupiterInitialFirmwareUpdateCompat
            (lib.lowPrio (
              pkgs.runCommand "steamos-update-stubs" { } ''
                mkdir -p $out/bin
                # steamos-update: stub exits 7 (no update) or 8 (reboot needed).
                # Jovian (2026-06) renamed this top-level stub to holo-update;
                # install it under the name Steam still invokes.
                cp ${pkgs.jovian-stubs}/bin/holo-update $out/bin/steamos-update
                # steamos-update-rauc: RAUC-based update check — always no entries on Jovian NixOS
                printf '#!/bin/sh\necho "-- No entries --"\nexit 0\n' > $out/bin/steamos-update-rauc
                chmod +x $out/bin/steamos-update-rauc
              ''
            ))
          ];

          # Expose steamos-polkit-helpers at the hardcoded path Steam expects.
          # Scripts call jovian stubs directly (no pkexec needed — stubs don't require
          # root and just check the current kernel symlink to report update status).
          systemd.tmpfiles.rules = [
            # Sentinel visible inside steam-runtime container (/run/ is shared, /etc/ is not)
            "d /run/jovian 0755 root root -"
            "f /run/jovian/jupiter-ran-initial-firmware-update 0444 root root -"
            # Compat polkit helpers dir at the hardcoded path Steam expects
            "L+ /usr/bin/steamos-polkit-helpers - - - - ${steamosPolkitHelpersCompat}"
            # The steam-runtime container maps the host's /usr/bin/ to /bin/ inside
            # the container.  Without /usr/bin/sh on the host, the container has no
            # /bin/sh, so every #!/bin/sh script (jovian stubs, polkit helpers) fails
            # with exit 127.  Add /usr/bin/sh so the container gets a working shell.
            "L+ /usr/bin/sh - - - - ${pkgs.bash}/bin/sh"
            # Drop-in to redirect the steam-launcher service at the current system's
            # steam binary (which includes our FHS steamos-polkit-helpers/ additions).
            # The Jovian gamescope-session hardcodes the steam path at build time;
            # this drop-in overrides ExecStart to use the up-to-date wrapper.
            # /etc/systemd/user/ is read-only on NixOS; use the user's home dir instead.
            # NixOS may create ~/.config/systemd/ as root — fix ownership so tmpfiles
            # does not reject the unsafe path transition daniel→root.
            "z /home/daniel/.config/systemd 0755 daniel daniel -"
            "z /home/daniel/.config/systemd/user 0755 daniel daniel -"
            "d /home/daniel/.config/systemd/user/steam-launcher.service.d 0755 daniel daniel -"
            "L+ /home/daniel/.config/systemd/user/steam-launcher.service.d/99-fhs-override.conf - - - - ${pkgs.writeText "steam-launcher-fhs-override.conf" ''
              [Service]
              ExecStart=
              ExecStart=${config.programs.steam.package}/bin/steam -steamdeck -steamos3 -gamepadui
            ''}"
          ];

          # Inject steamos-polkit-helpers into the Steam FHS environment.
          # buildFHSEnv maps $out/bin/* → /usr/bin/* inside the container, so
          # steamosPolkitHelpersFHS's $out/bin/steamos-polkit-helpers/ appears as
          # /usr/bin/steamos-polkit-helpers/ in the pressure-vessel container.
          programs.steam.extraPackages = [ steamosPolkitHelpersFHS ];
        }
      )

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
        # The deck's "Switch to Desktop" target is the Plasma session
        # (desktopSession = "plasma" below) and it runs its own SDDM autologin, so
        # it opts back into Plasma now that it's off by default fleet-wide. This
        # also keeps the greetd/ReGreet greeter off here (its default is
        # niri && !plasma), avoiding a second display manager.
        lyte.desktop.plasma.enable = true;

        environment.systemPackages = with pkgs; [
          steamdeck-firmware
          steam-rom-manager
          shipwright # Ship of Harkinian — OoT PC port
          hidapi
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

      {
        # Home-theater dock display management. This deck lives docked to the
        # living-room TV but is also used handheld. It was once found docked
        # with the built-in LCD panel lit at full brightness on a static Plasma
        # desktop, causing temporary image retention on the LCD.
        #
        # powerdevil's idle screen-off is global (it can't target one output)
        # and a ScreenSaver inhibit does not reliably stop its DPMS screen-off,
        # so we take powerdevil out of display-blanking (keeping the TV
        # structurally safe) and manage the built-in panel ourselves:
        #   - steamdeck-dock-panel disables the built-in panel while docked and
        #     re-enables it when undocked.
        #   - steamdeck-internal-idle turns the built-in panel's backlight off
        #     on idle when undocked (on AC as well as battery), never the TV.

        systemd.user.services.steamdeck-dock-panel = {
          description = "Drive only the TV when docked; keep the built-in panel off";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          path = [
            pkgs.kdePackages.libkscreen # kscreen-doctor
            pkgs.kdePackages.kconfig # kwriteconfig6
            pkgs.jq
            config.systemd.package # udevadm
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = pkgs.writeShellScript "steamdeck-dock-panel" (
              builtins.readFile ./steamdeck-dock-panel.sh
            );
          };
        };

        # Idle-off the built-in panel (only) when undocked. swayidle detects
        # session idle via KWin's ext-idle-notify; the helper blanks the panel
        # backlight and no-ops when docked so the TV is never touched.
        systemd.user.services.steamdeck-internal-idle =
          let
            internalBlank = pkgs.writeShellScript "steamdeck-internal-blank" (
              builtins.readFile ./steamdeck-internal-blank.sh
            );
          in
          {
            description = "Turn off the built-in panel on idle when undocked";
            wantedBy = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            path = [
              pkgs.kdePackages.libkscreen # kscreen-doctor
              pkgs.jq
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "5s";
              ExecStart =
                "${pkgs.swayidle}/bin/swayidle -w "
                + "timeout 600 '${internalBlank} off' "
                + "resume '${internalBlank} on'";
            };
          };

        # Let the session (wheel) write the built-in panel backlight so the idle
        # helper can power it down without root. Mirrors the status-LED rule
        # below. bl_power=4 powers the backlight down; brightness=0 is the floor.
        services.udev.extraRules = ''
          SUBSYSTEM=="backlight", KERNEL=="amdgpu_bl0", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp wheel /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"
        '';
      }

      {
        # Status/charger LED ("status:white"). Effective brightness is
        #   brightness * led_brightness_multiplier   (both 0-100)
        # and both attrs are root-only by default, so the LED can't be adjusted
        # without sudo (which is why Steam's "Settings -> Display -> Status LED
        # Brightness" slider — it writes the multiplier as the session user —
        # couldn't change it).
        #
        # On device-add we: (1) seed `brightness`=100 as the base so the
        # multiplier alone controls the level, and (2) hand both files to the
        # `wheel` group so they're writable without sudo. We deliberately do NOT
        # seed the multiplier — Steam owns/restores it (saved in its config and
        # re-applied on session start), so leaving it at the firmware default
        # (0/off) at boot avoids a brief flash-to-full before Steam restores
        # your level. Adjust via the Steam slider, or live:
        #   echo <0-100> > /sys/class/leds/status:white/led_brightness_multiplier
        # Applies to both Steam Decks (LCD + OLED) via the shared leds_steamdeck
        # driver; the KERNEL match no-ops if the LED isn't present.
        services.udev.extraRules = ''
          SUBSYSTEM=="leds", KERNEL=="status:white", ACTION=="add", ATTR{brightness}="100", RUN+="${pkgs.coreutils}/bin/chgrp wheel /sys/class/leds/%k/brightness /sys/class/leds/%k/led_brightness_multiplier", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/%k/brightness /sys/class/leds/%k/led_brightness_multiplier"
        '';
      }
    ]
  );
}
