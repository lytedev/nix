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
          errands # task/reminder manager (libadwaita)
          endeavour # GNOME Todo - task manager with GNOME Online Accounts integration

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

      # SMS TUI scripts (DE-agnostic, for SSH access)
      # Provides terminal-based SMS interface using skim (fuzzy finder) and mmcli
      {
        environment.systemPackages = with pkgs; [
          skim # Rust fuzzy finder (sk command)

          # sms-send: Send an SMS message
          # Usage: sms-send +15551234567 "message" OR echo "message" | sms-send +15551234567
          (writeShellScriptBin "sms-send" ''
            set -euo pipefail

            usage() {
              echo "Usage: sms-send <phone-number> [message]"
              echo "       echo 'message' | sms-send <phone-number>"
              echo ""
              echo "Phone number formats: +15551234567, 5551234567 (US +1 auto-added)"
              exit 1
            }

            [ $# -lt 1 ] && usage

            PHONE="$1"
            shift

            # Auto-add +1 for 10-digit US numbers
            if [[ "$PHONE" =~ ^[0-9]{10}$ ]]; then
              PHONE="+1$PHONE"
            elif [[ ! "$PHONE" =~ ^\+ ]]; then
              echo "Warning: Phone number doesn't start with +, assuming local format"
            fi

            # Get message from args or stdin
            if [ $# -gt 0 ]; then
              MESSAGE="$*"
            else
              MESSAGE=$(cat)
            fi

            [ -z "$MESSAGE" ] && { echo "Error: Empty message"; exit 1; }

            # Find modem
            MODEM=$(${pkgs.modemmanager}/bin/mmcli -L | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/Modem/\d+' | head -1)
            [ -z "$MODEM" ] && { echo "Error: No modem found"; exit 1; }

            # Create and send SMS
            SMS_PATH=$(${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-create-sms="number='$PHONE',text='$MESSAGE'" | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/SMS/\d+')
            [ -z "$SMS_PATH" ] && { echo "Error: Failed to create SMS"; exit 1; }

            ${pkgs.modemmanager}/bin/mmcli -s "$SMS_PATH" --send
            echo "Sent to $PHONE"
          '')

          # sms-delete: Delete SMS messages
          # Usage: sms-delete <index> OR sms-delete --conversation +15551234567
          (writeShellScriptBin "sms-delete" ''
            set -euo pipefail

            usage() {
              echo "Usage: sms-delete <sms-index>"
              echo "       sms-delete --conversation <phone-number>"
              echo ""
              echo "Options:"
              echo "  <sms-index>              Delete single message by index"
              echo "  --conversation <number>  Delete all messages for a phone number"
              exit 1
            }

            [ $# -lt 1 ] && usage

            MODEM=$(${pkgs.modemmanager}/bin/mmcli -L | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/Modem/\d+' | head -1)
            [ -z "$MODEM" ] && { echo "Error: No modem found"; exit 1; }

            if [ "$1" = "--conversation" ] || [ "$1" = "-c" ]; then
              [ $# -lt 2 ] && usage
              PHONE="$2"
              # Normalize phone number
              if [[ "$PHONE" =~ ^[0-9]{10}$ ]]; then
                PHONE="+1$PHONE"
              fi

              echo "Deleting all messages for $PHONE..."
              COUNT=0
              for idx in $(${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-list-sms | ${pkgs.gnugrep}/bin/grep -oP '/SMS/\K\d+'); do
                SMS_NUM=$(${pkgs.modemmanager}/bin/mmcli -s "$idx" | ${pkgs.gnugrep}/bin/grep -oP "number:\s*'\K[^']+" || true)
                if [ "$SMS_NUM" = "$PHONE" ]; then
                  ${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-delete-sms="$idx"
                  COUNT=$((COUNT + 1))
                fi
              done
              echo "Deleted $COUNT message(s)"
            else
              IDX="$1"
              ${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-delete-sms="$IDX"
              echo "Deleted message $IDX"
            fi
          '')

          # sms-compose: Compose SMS in editor
          # Usage: sms-compose [phone-number]
          (writeShellScriptBin "sms-compose" ''
            set -euo pipefail

            PHONE="''${1:-}"
            TMPFILE=$(mktemp /tmp/sms-compose.XXXXXX)
            trap 'rm -f "$TMPFILE"' EXIT

            # Create template
            cat > "$TMPFILE" << 'EOF'
# SMS Compose - Lines starting with # are ignored
# Enter phone number on the "To:" line (or it was pre-filled)
# Write your message below the blank line
# Save and exit to send, empty message to cancel

EOF
            if [ -n "$PHONE" ]; then
              echo "To: $PHONE" >> "$TMPFILE"
            else
              echo "To: " >> "$TMPFILE"
            fi
            cat >> "$TMPFILE" << 'EOF'

EOF

            # Open editor
            ''${EDITOR:-${pkgs.vim}/bin/vim} "$TMPFILE"

            # Parse result
            TO=$(${pkgs.gnugrep}/bin/grep -m1 '^To:' "$TMPFILE" | ${pkgs.gnused}/bin/sed 's/^To:\s*//' || true)
            MESSAGE=$(${pkgs.gnused}/bin/sed '1,/^To:/d' "$TMPFILE" | ${pkgs.gnugrep}/bin/grep -v '^#' | ${pkgs.gnused}/bin/sed '/^$/d')

            [ -z "$TO" ] && { echo "Cancelled: No recipient"; exit 0; }
            [ -z "$MESSAGE" ] && { echo "Cancelled: Empty message"; exit 0; }

            echo "---"
            echo "To: $TO"
            echo "Message: $MESSAGE"
            echo "---"
            read -p "Send? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              echo "$MESSAGE" | sms-send "$TO"
            else
              echo "Cancelled"
            fi
          '')

          # sms-list: List SMS conversations with skim preview
          (writeShellScriptBin "sms-list" ''
            set -euo pipefail

            MODEM=$(${pkgs.modemmanager}/bin/mmcli -L | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/Modem/\d+' | head -1)
            [ -z "$MODEM" ] && { echo "Error: No modem found"; exit 1; }

            # Build conversation list
            TMPDIR=$(mktemp -d)
            trap 'rm -rf "$TMPDIR"' EXIT

            # Collect all messages into per-phone files
            for idx in $(${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-list-sms 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '/SMS/\K\d+' || true); do
              INFO=$(${pkgs.modemmanager}/bin/mmcli -s "$idx" 2>/dev/null) || continue
              PHONE=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP "number:\s*'\K[^']+" || true)
              [ -z "$PHONE" ] && continue
              STATE=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP "state:\s*'\K[^']+" || echo "unknown")
              TEXT=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP "text:\s*'\K[^']+" || echo "")
              TIME=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP "timestamp:\s*'\K[^']+" || echo "")

              # Direction: received or sent
              if [ "$STATE" = "received" ]; then
                DIR="<"
              else
                DIR=">"
              fi

              # Store message in conversation file (use safe filename)
              SAFE_PHONE=$(echo "$PHONE" | ${pkgs.gnused}/bin/sed 's/[^a-zA-Z0-9+]/_/g')
              CONV_FILE="$TMPDIR/conv_$SAFE_PHONE"
              # Store phone number in first line if file is new
              [ ! -f "$CONV_FILE" ] && echo "PHONE:$PHONE" > "$CONV_FILE"
              echo "$TIME|$DIR|$idx|$TEXT" >> "$CONV_FILE"
            done

            # Check if we have any conversations
            CONV_COUNT=$(find "$TMPDIR" -name 'conv_*' 2>/dev/null | wc -l)
            if [ "$CONV_COUNT" -eq 0 ]; then
              echo "No messages found"
              exit 0
            fi

            # Create list for skim
            LIST_FILE="$TMPDIR/list"
            for CONV_FILE in "$TMPDIR"/conv_*; do
              [ -f "$CONV_FILE" ] || continue
              PHONE=$(head -1 "$CONV_FILE" | ${pkgs.gnused}/bin/sed 's/^PHONE://')
              MSG_COUNT=$(($(wc -l < "$CONV_FILE") - 1))
              LAST_MSG=$(tail -1 "$CONV_FILE" | cut -d'|' -f4 | cut -c1-40)
              echo "$PHONE ($MSG_COUNT) $LAST_MSG" >> "$LIST_FILE"
            done

            [ ! -s "$LIST_FILE" ] && { echo "No messages found"; exit 0; }

            # Preview script
            PREVIEW_SCRIPT="$TMPDIR/preview.sh"
            cat > "$PREVIEW_SCRIPT" << 'PREVIEW'
#!/usr/bin/env bash
PHONE=$(echo "$1" | cut -d' ' -f1)
TMPDIR="$2"
# Find the conversation file for this phone
for f in "$TMPDIR"/conv_*; do
  [ -f "$f" ] || continue
  FILE_PHONE=$(head -1 "$f" | sed 's/^PHONE://')
  if [ "$FILE_PHONE" = "$PHONE" ]; then
    echo "=== $PHONE ==="
    echo ""
    tail -n +2 "$f" | sort | while IFS='|' read -r TIME DIR IDX TEXT; do
      if [ "$DIR" = "<" ]; then
        echo "< $TEXT"
      else
        echo "> $TEXT"
      fi
    done
    exit 0
  fi
done
PREVIEW
            chmod +x "$PREVIEW_SCRIPT"

            # Run skim
            SELECTED=$(${pkgs.skim}/bin/sk \
              --height=100% \
              --preview="$PREVIEW_SCRIPT {} $TMPDIR" \
              --preview-window='down:50%:wrap' \
              --cycle \
              --header='Enter=reply  Ctrl-N=new  Ctrl-D=delete conv  Ctrl-R=refresh' \
              --bind='ctrl-n:abort+execute(sms-compose)' \
              --bind='ctrl-d:abort+execute(sms-delete --conversation $(echo {} | cut -d" " -f1))' \
              --bind='ctrl-r:abort+execute(sms-list)' \
              < "$LIST_FILE" || true)

            if [ -n "$SELECTED" ]; then
              PHONE=$(echo "$SELECTED" | cut -d' ' -f1)
              sms-compose "$PHONE"
            fi
          '')

          # sms: Main entry point
          (writeShellScriptBin "sms" ''
            set -euo pipefail

            CHOICE=$(printf '%s\n' "View Conversations" "Compose New" "Sync Messages" | \
              ${pkgs.skim}/bin/sk \
                --height=100% \
                --header='SMS Menu' \
                --cycle \
              || true)

            case "$CHOICE" in
              "View Conversations")
                exec sms-list
                ;;
              "Compose New")
                exec sms-compose
                ;;
              "Sync Messages")
                MODEM=$(${pkgs.modemmanager}/bin/mmcli -L | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/Modem/\d+' | head -1)
                if [ -n "$MODEM" ]; then
                  echo "Modem: $MODEM"
                  ${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-list-sms
                else
                  echo "No modem found"
                fi
                read -p "Press Enter to continue..."
                exec sms
                ;;
              *)
                echo "Cancelled"
                ;;
            esac
          '')
        ];
      }

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
