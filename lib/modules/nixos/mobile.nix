{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.mobile;
in
{
  options = {
    lyte = {
      mobile = {
        enable = lib.mkEnableOption "Enable mobile (Phosh) configuration for phones";
        user = lib.mkOption {
          type = lib.types.str;
          default = "daniel";
          description = "The user to run the Phosh session";
        };
        scale = lib.mkOption {
          type = lib.types.float;
          default = 2.0;
        };
        stage1Ssh = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable stage-1 SSH for debugging (dropbear, passwordless root)";
        };
        silentBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Hide boot messages (set false to show them for debugging)";
        };
        fbkeyboard = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable framebuffer on-screen keyboard for TTY/console use";
        };
        useStevia = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use Stevia keyboard instead of Squeekboard (experimental - requires packaging)";
        };
        cellBroadcast = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable cell broadcast daemon for emergency alerts";
        };
        mms = {
          enable = lib.mkEnableOption "Enable MMS (Multimedia Messaging Service) support via mmsd-tng";
          carrierMMSC = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "http://mms.example.com/mms/wapenc";
            description = "MMS Center URL from your carrier (required for MMS)";
          };
          mmsAPN = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "mms";
            description = "APN for MMS from your carrier (required for MMS)";
          };
          carrierMMSProxy = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "proxy.example.com:8080";
            description = "MMS proxy server (leave empty if not required by carrier)";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Generic mobile/phosh settings (mobile-nixos specific settings are in lib/host.nix mobileHost)
      {
        # Allow olm (used by chatty for Matrix) - it has known vulnerabilities but is needed
        nixpkgs.config.permittedInsecurePackages = [
          "olm-3.2.16"
        ];

        # Phosh desktop environment
        services.xserver.desktopManager.phosh = {
          enable = true;
          user = cfg.user;
          group = "users";
          phocConfig = {
            xwayland = "immediate"; # better x11 app compat
            outputs = {
              DSI-1 = {
                scale = cfg.scale;
              };
            };
          };
        };

        # Phone calling support
        programs.calls.enable = true;

        # ModemManager with quick suspend/resume for better call handling
        systemd.services.ModemManager.serviceConfig.ExecStart = [
          ""
          "${pkgs.modemmanager}/sbin/ModemManager --test-quick-suspend-resume"
        ];

        # Mobile hardware support
        hardware.sensor.iio.enable = true;
        services.geoclue2.enable = true;

        # Camera access - add user to video group for /dev/video* access
        users.users.${cfg.user}.extraGroups = [ "video" ];

        # Flash LED permissions for megapixels camera
        # sysfs permissions can't be set via udev, so we use tmpfiles.d
        systemd.tmpfiles.rules = [
          # Set permissions on camera flash LED strobe files (megapixels needs write access)
          "z /sys/class/leds/white:flash/flash_strobe 0664 root video -"
          "z /sys/class/leds/white:flash/flash_timeout 0664 root video -"
        ];

        # feedbackd for haptic feedback (enabled by phosh, but we configure the profile)
        # Use `gsettings set org.sigxcpu.feedbackd profile silent` to disable vibration
        # Or use the feedbackd-toggle script we provide
        programs.feedbackd.enable = true;

        # Pipewire for audio
        services.pipewire.enable = true;

        # Mobile apps
        environment.systemPackages = with pkgs; [
          # Browser
          firefox

          # Communication
          chatty # SMS/MMS messaging
          gnome-contacts # Contact management (works with evolution-data-server)

          # Email
          geary # Mobile-friendly email client

          # Music & Podcasts
          amberol # Minimal music player, perfect for mobile
          gnome-podcasts # Lightweight podcast app

          # Camera and its dependencies
          megapixels
          v4l-utils # for v4l2-ctl debugging
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good # v4l2 support

          # File manager
          nautilus

          # Productivity
          gnome-calculator
          gnome-calendar
          gnome-notes # simple note-taking

          # Media
          loupe # image viewer
          celluloid # video player (mpv frontend)
          evince # document/PDF viewer

          # Voice Recording
          gnome-sound-recorder # simple voice memo / audio recording

          # Utilities
          gnome-weather
          gnome-maps

          # Terminals
          foot # Lightweight, works well without GPU acceleration
          ghostty # Full-featured, may have OpenGL issues on Mali-400

          # Fonts
          iosevkaLyteTerm

          # On-screen keyboard (squeekboard is included; stevia is optional replacement)
          squeekboard

          # Phosh settings app (mobile-specific settings beyond GNOME Settings)
          phosh-mobile-settings

          # Vibrator control script
          (writeShellScriptBin "vibrator-toggle" ''
            #!/usr/bin/env bash
            # Toggle feedbackd haptic feedback profile between full and silent
            current=$(${pkgs.glib}/bin/gsettings get org.sigxcpu.feedbackd profile 2>/dev/null || echo "'full'")
            if [ "$current" = "'silent'" ]; then
              ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
              echo "Vibration enabled (full)"
            else
              ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
              echo "Vibration disabled (silent)"
            fi
          '')

          (writeShellScriptBin "vibrator-off" ''
            ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
            echo "Vibration disabled"
          '')

          (writeShellScriptBin "vibrator-on" ''
            ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
            echo "Vibration enabled"
          '')
        ];

        # Polkit rules to allow modem access without password prompts
        # Fixes the annoying "system policy" password prompt for SMS/calls
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id.indexOf("org.freedesktop.ModemManager1") == 0 &&
                subject.isInGroup("dialout")) {
              return polkit.Result.YES;
            }
          });
        '';

        # Fonts
        fonts.packages = [
          pkgs.iosevkaLyteTerm
          (
            if builtins.hasAttr "nerd-fonts" pkgs then
              pkgs.nerd-fonts.symbols-only
            else
              (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
          )
        ];

        # Qt apps should use wayland
        environment.sessionVariables = {
          QT_QPA_PLATFORM = "wayland";
        };

        # XDG portal for desktop integration
        xdg.portal = {
          enable = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-gtk
            pkgs.xdg-desktop-portal-phosh # Phosh-specific portal (account, app chooser)
          ];
        };
      }

      # Framebuffer on-screen keyboard for TTY/console
      (lib.mkIf cfg.fbkeyboard {
        # Enable uinput kernel module (required for fbkeyboard to inject keypresses)
        boot.kernelModules = [ "uinput" ];

        # Make uinput accessible to users in input group
        services.udev.extraRules = ''
          KERNEL=="uinput", GROUP="input", MODE="0660"
        '';

        # Add user to input group for uinput access
        users.users.${cfg.user}.extraGroups = [ "input" ];

        environment.systemPackages = [
          pkgs.fbkeyboard
        ];

        systemd.services = {
          # Fallback keyboard on TTY1 - stops when graphical session starts
          # This ensures you can still type if Phosh fails to start
          fbkeyboard-tty1 = {
            description = "Framebuffer on-screen keyboard on TTY1 (fallback)";
            wantedBy = [ "multi-user.target" ];
            after = [ "systemd-vconsole-setup.service" ];
            # Stop this service when display-manager starts (Phosh takes over TTY1)
            conflicts = [ "display-manager.service" ];

            serviceConfig = {
              ExecStart = "${pkgs.fbkeyboard}/bin/fbkeyboard";
              Restart = "on-failure";
              RestartSec = "2s";
              StandardInput = "tty";
              StandardOutput = "tty";
              TTYPath = "/dev/tty1";
              TTYReset = "yes";
              TTYVHangup = "yes";
            };
          };

          # Always-available keyboard on TTY2
          fbkeyboard-tty2 = {
            description = "Framebuffer on-screen keyboard on TTY2";
            wantedBy = [ "multi-user.target" ];
            after = [ "systemd-vconsole-setup.service" ];

            serviceConfig = {
              ExecStart = "${pkgs.fbkeyboard}/bin/fbkeyboard";
              Restart = "on-failure";
              RestartSec = "2s";
              StandardInput = "tty";
              StandardOutput = "tty";
              TTYPath = "/dev/tty2";
              TTYReset = "yes";
              TTYVHangup = "yes";
            };
          };
        };
      })

      # Stevia keyboard (experimental replacement for squeekboard)
      # Stevia provides word completion, cursor navigation, and other enhancements
      # Phosh 0.50+ uses mobi.phosh.OSK.service systemd user unit to launch the OSK
      (lib.mkIf cfg.useStevia {
        environment.systemPackages = [
          pkgs.stevia
        ];

        # Override the Phosh OSK systemd user service to use Stevia instead of Squeekboard
        systemd.user.services."mobi.phosh.OSK" = {
          description = "Phosh On-Screen Keyboard (Stevia)";
          partOf = [ "phosh.service" ];
          after = [ "phosh.service" ];

          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.stevia}/bin/phosh-osk-stevia";
            Restart = "on-failure";
          };

          wantedBy = [ "phosh.service" ];
        };
      })

      # Cell broadcast daemon for emergency alerts
      (lib.mkIf cfg.cellBroadcast {
        environment.systemPackages = [
          pkgs.cellbroadcastd
        ];

        # Link the systemd user service from the package
        systemd.user.services.cellbroadcastd = {
          description = "Cellbroadcast Daemon";
          wantedBy = [ "default.target" ];
          after = [ "ModemManager.service" ];

          serviceConfig = {
            Type = "dbus";
            BusName = "org.freedesktop.cbd";
            ExecStart = "${pkgs.cellbroadcastd}/libexec/cellbroadcastd";
          };
        };
      })

      # MMS support via mmsd-tng
      # Chatty integrates with mmsd-tng for sending/receiving MMS messages
      (lib.mkIf cfg.mms.enable {
        environment.systemPackages = [
          pkgs.mmsd-tng
        ];

        # mmsd-tng systemd user service
        # Runs as user service since it needs access to user's config in ~/.mms/
        systemd.user.services.mmsd-tng = {
          description = "MMS Daemon (mmsd-tng)";
          wantedBy = [ "default.target" ];
          after = [ "ModemManager.service" ];

          serviceConfig = {
            Type = "dbus";
            BusName = "org.ofono.mms";
            ExecStart = "${pkgs.mmsd-tng}/bin/mmsdtng";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        # Create default MMS configuration if carrier settings are provided
        # The config is written to the user's home directory
        system.activationScripts.mmsd-config = lib.mkIf (cfg.mms.carrierMMSC != "") ''
                    # Get the user's actual home directory from passwd (handles custom home paths)
                    USER_HOME=$(getent passwd ${cfg.user} | cut -d: -f6)
                    MMS_DIR="$USER_HOME/.mms/modemmanager"
                    mkdir -p "$MMS_DIR"

                    # Only create config if it doesn't exist (don't overwrite user customizations)
                    if [ ! -f "$MMS_DIR/ModemManagerSettings" ]; then
                      cat > "$MMS_DIR/ModemManagerSettings" << 'MMSEOF'
          [Modem Manager]
          CarrierMMSC=${cfg.mms.carrierMMSC}
          MMS_APN=${cfg.mms.mmsAPN}
          CarrierMMSProxy=${if cfg.mms.carrierMMSProxy == "" then "NULL" else cfg.mms.carrierMMSProxy}
          AutoProcessOnConnection=true
          AutoProcessSMSWAP=true
          MMSEOF
                      chown -R ${cfg.user}:users "$MMS_DIR"
                      chmod 700 "$USER_HOME/.mms"
                      chmod 600 "$MMS_DIR/ModemManagerSettings"
                    fi
        '';
      })

      # Audio roles configuration for wireplumber
      # This enables independent volume control for different audio types
      # (media, alarms, ringtones, cell broadcasts, etc.)
      {
        services.pipewire.wireplumber.extraConfig = {
          "50-audio-roles" = {
            "wireplumber.settings" = {
              # Enable role-based audio policy
              "default-audio.sink.role-properties" = true;
            };
          };
        };
      }
    ]
  );
}
