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

        # Set proximity near level for stk3310 so iio-sensor-proxy reports "near" state
        # (used by phosh to blank screen during calls)
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="iio", TEST=="in_proximity_raw", ENV{PROXIMITY_NEAR_LEVEL}="250"
        '';

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
          # Browser (policies configured via environment.etc below)
          firefox

          # Communication
          chatty # SMS/MMS messaging
          gnome-contacts # Contact management (works with evolution-data-server)
          fractal # Matrix

          # Email
          geary # Mobile-friendly email client

          # Music & Podcasts
          amberol # Minimal music player, perfect for mobile
          gnome-podcasts # Lightweight podcast app

          # Camera and its dependencies
          # Mali-400 (lima) only supports GLES 2.0, but GTK 4.18+ requires GLES 3.0.
          # Force software rendering so megapixels can create a GL context.
          (pkgs.symlinkJoin {
            name = "megapixels-wrapped";
            paths = [ megapixels ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/megapixels \
                --set LIBGL_ALWAYS_SOFTWARE 1 \
                --set GSK_RENDERER cairo
            '';
          })
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

        # Firefox mobile-friendly policies (from postmarketOS mobile-config-firefox)
        # Disables telemetry/bloat, sets DuckDuckGo default, installs uBlock Origin
        environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
          policies = {
            DisableFirefoxScreenshots = true;
            DisableFirefoxStudies = true;
            DisableTelemetry = true;
            DisablePocket = true;
            NoDefaultBookmarks = true;
            OverrideFirstRunPage = "";
            OverridePostUpdatePage = "";

            Homepage = {
              URL = "about:home";
              Locked = false;
              StartPage = "homepage";
            };

            FirefoxHome = {
              Search = true;
              TopSites = false;
              Highlights = false;
              Pocket = false;
              Snippets = false;
              Locked = false;
            };

            SearchEngines = {
              Default = "DuckDuckGo";
              Remove = [
                "Amazon.com"
                "Amazon.co.uk"
                "Amazon.de"
                "Amazon.fr"
                "Amazon.ca"
                "Amazon.co.jp"
                "Amazon.com.au"
                "Amazon.es"
                "Amazon.in"
                "Amazon.it"
                "Amazon.nl"
                "Amazon.se"
                "Bing"
                "eBay"
                "Google"
              ];
            };

            Preferences = {
              "dom.private-attribution.submission.enabled" = {
                Value = false;
                Status = "locked";
              };
            };

            UserMessaging = {
              WhatsNew = false;
              ExtensionRecommendations = false;
              FeatureRecommendations = false;
              UrlbarInterventions = false;
              SkipOnboarding = false;
            };

            ExtensionSettings = {
              "uBlock0@raymondhill.net" = {
                installation_mode = "normal_installed";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              };
            };
          };
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
      # Also reads from Chatty's SQLite database for historical messages
      # Integrates with GNOME contacts via evolution-data-server
      {
        environment.systemPackages = with pkgs; [
          skim # Rust fuzzy finder (sk command)
          sqlite # For querying Chatty's message database
          folks # For contact name lookups (folks-inspect)
          gawk # For parsing folks-inspect output

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
                SMS_NUM=$(${pkgs.modemmanager}/bin/mmcli -s "$idx" | ${pkgs.gnugrep}/bin/grep -oP 'number:\s*\K\S+' || true)
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
          # If no phone provided, shows contact picker
          (writeShellScriptBin "sms-compose" ''
                        set -euo pipefail

                        PHONE="''${1:-}"

                        # If no phone provided, offer contact picker
                        if [ -z "$PHONE" ]; then
                          # Build contacts list for picker
                          CONTACTS_TMP=$(mktemp)
                          trap 'rm -f "$CONTACTS_TMP"' EXIT

                          # Get contacts from folks (set up environment for SSH sessions)
                          if command -v folks-inspect >/dev/null 2>&1; then
                            export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
                            export XDG_DATA_DIRS="''${XDG_DATA_DIRS:+$XDG_DATA_DIRS:}${pkgs.folks}/share/gsettings-schemas/folks-${pkgs.folks.version}:/run/current-system/sw/share"
                            echo "individuals" | timeout 5 ${pkgs.folks}/bin/folks-inspect 2>/dev/null | ${pkgs.gawk}/bin/awk '
                              /^[^ ]/ { name = $0; gsub(/^[ \t]+|[ \t]+$/, "", name) }
                              /phone-numbers:/ {
                                getline
                                while (/^[ \t]+/) {
                                  phone = $0
                                  gsub(/^[ \t]+|[ \t]+$/, "", phone)
                                  # Keep formatted phone for display
                                  if (phone != "" && name != "") {
                                    print name " <" phone ">"
                                  }
                                  if (!getline) break
                                }
                              }
                            ' >> "$CONTACTS_TMP" 2>/dev/null || true
                          fi

                          # Also try EDS sqlite
                          EDS_DB=$(find ~/.local/share/evolution/addressbook -name "contacts.db" 2>/dev/null | head -1)
                          if [ -n "$EDS_DB" ] && [ -f "$EDS_DB" ]; then
                            ${pkgs.sqlite}/bin/sqlite3 "$EDS_DB" "
                              SELECT f.full_name || ' <' || p.value || '>'
                              FROM folder_id f
                              JOIN folder_id_phone_list p ON f.uid = p.uid
                              WHERE p.value IS NOT NULL AND LENGTH(p.value) > 0 AND f.full_name IS NOT NULL
                            " 2>/dev/null >> "$CONTACTS_TMP" || true
                          fi

                          # Add option to enter manually
                          echo "[Enter number manually]" >> "$CONTACTS_TMP"

                          if [ -s "$CONTACTS_TMP" ]; then
                            SELECTED=$(${pkgs.skim}/bin/sk \
                              --height=100% \
                              --header='Select contact or enter phone number' \
                              --cycle \
                              < "$CONTACTS_TMP" || true)

                            if [ -n "$SELECTED" ] && [ "$SELECTED" != "[Enter number manually]" ]; then
                              # Extract phone from "Name <phone>" format
                              PHONE=$(echo "$SELECTED" | ${pkgs.gnused}/bin/sed 's/.*<\(.*\)>/\1/' | ${pkgs.gnused}/bin/sed 's/[^0-9+]//g')
                            fi
                          fi
                        fi

                        TMPFILE=$(mktemp /tmp/sms-compose.XXXXXX)
                        # Update trap to clean both files
                        trap 'rm -f "$TMPFILE" "$CONTACTS_TMP" 2>/dev/null' EXIT

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
          # Reads from both Chatty's SQLite database and ModemManager
          # Integrates with GNOME contacts for name display
          (writeShellScriptBin "sms-list" ''
                        set -euo pipefail

                        # Build conversation list
                        TMPDIR=$(mktemp -d)
                        trap 'rm -rf "$TMPDIR"' EXIT

                        # Chatty database location (in purple directory, not .local/share)
                        CHATTY_DB="$HOME/.purple/chatty/db/chatty-history.db"

                        # Build contacts lookup cache (phone -> name)
                        CONTACTS_CACHE="$TMPDIR/contacts"
                        touch "$CONTACTS_CACHE"

                        # Function to normalize phone numbers for comparison (remove non-digits except +)
                        normalize_phone() {
                          echo "$1" | ${pkgs.gnused}/bin/sed 's/[^0-9+]//g'
                        }

                        # Build contacts cache from folks (evolution-data-server)
                        # folks-inspect needs GSettings schemas and D-Bus session for SSH use
                        if command -v folks-inspect >/dev/null 2>&1; then
                          # Set up environment for SSH sessions (graphical sessions have this already)
                          export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
                          # Add GSettings schema path for folks
                          export XDG_DATA_DIRS="''${XDG_DATA_DIRS:+$XDG_DATA_DIRS:}${pkgs.folks}/share/gsettings-schemas/folks-${pkgs.folks.version}:/run/current-system/sw/share"
                          # Use timeout to avoid hanging if D-Bus isn't accessible
                          echo "individuals" | timeout 5 ${pkgs.folks}/bin/folks-inspect 2>/dev/null | ${pkgs.gawk}/bin/awk '
                            /^[^ ]/ { name = $0; gsub(/^[ \t]+|[ \t]+$/, "", name) }
                            /phone-numbers:/ {
                              getline
                              while (/^[ \t]+/) {
                                phone = $0
                                gsub(/^[ \t]+|[ \t]+$/, "", phone)
                                gsub(/[^0-9+]/, "", phone)
                                if (phone != "" && name != "") {
                                  print phone "|" name
                                }
                                if (!getline) break
                              }
                            }
                          ' >> "$CONTACTS_CACHE" 2>/dev/null || true
                        fi

                        # Also try evolution-data-server's addressbook sqlite directly as fallback
                        EDS_DB=$(find ~/.local/share/evolution/addressbook -name "contacts.db" 2>/dev/null | head -1)
                        if [ -n "$EDS_DB" ] && [ -f "$EDS_DB" ]; then
                          ${pkgs.sqlite}/bin/sqlite3 -separator '|' "$EDS_DB" "
                            SELECT p.value, f.full_name
                            FROM folder_id f
                            JOIN folder_id_phone_list p ON f.uid = p.uid
                            WHERE p.value IS NOT NULL AND LENGTH(p.value) > 0
                          " 2>/dev/null >> "$CONTACTS_CACHE" || true
                        fi

                        # Function to lookup contact name by phone
                        lookup_contact() {
                          local PHONE="$1"
                          local NORM_PHONE=$(normalize_phone "$PHONE")
                          # Try exact match first, then suffix match (last 10 digits)
                          local NAME=$(${pkgs.gnugrep}/bin/grep -F "$NORM_PHONE" "$CONTACTS_CACHE" 2>/dev/null | head -1 | cut -d'|' -f2)
                          if [ -z "$NAME" ] && [ ''${#NORM_PHONE} -ge 10 ]; then
                            local SUFFIX="''${NORM_PHONE: -10}"
                            NAME=$(${pkgs.gnugrep}/bin/grep "$SUFFIX" "$CONTACTS_CACHE" 2>/dev/null | head -1 | cut -d'|' -f2)
                          fi
                          echo "$NAME"
                        }

                        # Function to add message to conversation file
                        add_message() {
                          local PHONE="$1"
                          local TIME="$2"
                          local DIR="$3"
                          local TEXT="$4"
                          local SOURCE="$5"

                          SAFE_PHONE=$(echo "$PHONE" | ${pkgs.gnused}/bin/sed 's/[^a-zA-Z0-9+]/_/g')
                          CONV_FILE="$TMPDIR/conv_$SAFE_PHONE"
                          [ ! -f "$CONV_FILE" ] && echo "PHONE:$PHONE" > "$CONV_FILE"
                          # Escape pipes in text to avoid parsing issues
                          TEXT_ESCAPED=$(echo "$TEXT" | ${pkgs.gnused}/bin/sed 's/|/¦/g')
                          echo "$TIME|$DIR|$SOURCE|$TEXT_ESCAPED" >> "$CONV_FILE"
                        }

                        # 1. Query Chatty's SQLite database for historical messages
                        if [ -f "$CHATTY_DB" ]; then
                          # Query messages with thread info
                          # Chatty schema: messages(id, thread_id, uid, body, time, direction, ...)
                          #                threads(id, name, alias, account_id, ...)
                          # direction: 1=incoming (received), -1=outgoing (sent)
                          ${pkgs.sqlite}/bin/sqlite3 -separator '|' "$CHATTY_DB" "
                            SELECT
                              COALESCE(t.name, 'Unknown') as phone,
                              datetime(m.time, 'unixepoch', 'localtime') as msg_time,
                              m.direction,
                              REPLACE(REPLACE(m.body, CHAR(10), ' '), CHAR(13), ' ') as body
                            FROM messages m
                            LEFT JOIN threads t ON m.thread_id = t.id
                            WHERE m.body IS NOT NULL AND LENGTH(m.body) > 0
                            ORDER BY m.time ASC
                          " 2>/dev/null | while IFS='|' read -r PHONE TIME DIRECTION TEXT; do
                            [ -z "$PHONE" ] && continue
                            # direction: 1=incoming (received), -1=outgoing (sent)
                            if [ "$DIRECTION" = "1" ]; then
                              DIR="<"
                            else
                              DIR=">"
                            fi
                            add_message "$PHONE" "$TIME" "$DIR" "$TEXT" "chatty"
                          done || true
                        fi

                        # 2. Also check ModemManager for any pending/new messages not yet in Chatty
                        MODEM=$(${pkgs.modemmanager}/bin/mmcli -L 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '/org/freedesktop/ModemManager1/Modem/\d+' | head -1 || true)
                        if [ -n "$MODEM" ]; then
                          for idx in $(${pkgs.modemmanager}/bin/mmcli -m "$MODEM" --messaging-list-sms 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '/SMS/\K\d+' || true); do
                            INFO=$(${pkgs.modemmanager}/bin/mmcli -s "$idx" 2>/dev/null) || continue
                            # mmcli outputs values without quotes, e.g. "number: +1234567890"
                            PHONE=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP 'number:\s*\K\S+' || true)
                            [ -z "$PHONE" ] && continue
                            STATE=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP 'state:\s*\K\S+' || echo "unknown")
                            TEXT=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP 'text:\s*\K.*' || echo "")
                            TIME=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP 'timestamp:\s*\K\S+' || echo "$(date '+%Y-%m-%d %H:%M:%S')")

                            if [ "$STATE" = "received" ]; then
                              DIR="<"
                            else
                              DIR=">"
                            fi
                            add_message "$PHONE" "$TIME" "$DIR" "$TEXT" "modem:$idx"
                          done
                        fi

                        # Check if we have any conversations
                        CONV_COUNT=$(find "$TMPDIR" -name 'conv_*' 2>/dev/null | wc -l)
                        if [ "$CONV_COUNT" -eq 0 ]; then
                          echo "No messages found"
                          if [ ! -f "$CHATTY_DB" ]; then
                            echo "(Chatty database not found at ~/.purple/chatty/db/chatty-history.db)"
                          fi
                          if [ -z "$MODEM" ]; then
                            echo "(No modem found)"
                          fi
                          exit 0
                        fi

                        # Create list for skim (sorted by most recent message)
                        LIST_FILE="$TMPDIR/list"
                        for CONV_FILE in "$TMPDIR"/conv_*; do
                          [ -f "$CONV_FILE" ] || continue
                          PHONE=$(head -1 "$CONV_FILE" | ${pkgs.gnused}/bin/sed 's/^PHONE://')
                          MSG_COUNT=$(($(wc -l < "$CONV_FILE") - 1))
                          # Get last message time and preview
                          LAST_LINE=$(tail -1 "$CONV_FILE")
                          LAST_TIME=$(echo "$LAST_LINE" | cut -d'|' -f1)
                          LAST_MSG=$(echo "$LAST_LINE" | cut -d'|' -f4 | ${pkgs.gnused}/bin/sed 's/¦/|/g' | cut -c1-30)
                          # Look up contact name
                          CONTACT_NAME=$(lookup_contact "$PHONE")
                          if [ -n "$CONTACT_NAME" ]; then
                            DISPLAY_NAME="$CONTACT_NAME"
                          else
                            DISPLAY_NAME="$PHONE"
                          fi
                          # Sort key is the timestamp (for sorting conversations by recency)
                          # Store phone in a way we can extract it later (after the display name)
                          echo "$LAST_TIME|$PHONE|$DISPLAY_NAME ($MSG_COUNT) $LAST_MSG" >> "$LIST_FILE"
                        done

                        # Sort by time (newest first) and remove the sort key, keep phone|display format
                        SORTED_LIST="$TMPDIR/list_sorted"
                        sort -t'|' -k1 -r "$LIST_FILE" | cut -d'|' -f2- > "$SORTED_LIST"

                        # Create display list (without phone prefix) for skim
                        DISPLAY_LIST="$TMPDIR/list_display"
                        cut -d'|' -f2- "$SORTED_LIST" > "$DISPLAY_LIST"

                        [ ! -s "$DISPLAY_LIST" ] && { echo "No messages found"; exit 0; }

                        # Map file: line number -> phone (for selection)
                        PHONE_MAP="$TMPDIR/phone_map"
                        cut -d'|' -f1 "$SORTED_LIST" > "$PHONE_MAP"

                        # Preview script - shows conversation history
                        # First arg is the selected line, second is tmpdir
                        PREVIEW_SCRIPT="$TMPDIR/preview.sh"
                        cat > "$PREVIEW_SCRIPT" << 'PREVIEW'
            #!/usr/bin/env bash
            SELECTION="$1"
            TMPDIR="$2"
            # Extract phone from display (first word before space or paren)
            # Since display might be "Name (N)" or "+1234 (N)", we need to find the matching conv file
            # Search all conv files for a matching display or phone
            for f in "$TMPDIR"/conv_*; do
              [ -f "$f" ] || continue
              FILE_PHONE=$(head -1 "$f" | sed 's/^PHONE://')
              # Check if selection starts with phone or if we can match
              if echo "$SELECTION" | grep -qF "$FILE_PHONE"; then
                PHONE="$FILE_PHONE"
                # Try to get contact name from the selection
                DISPLAY=$(echo "$SELECTION" | sed 's/ ([0-9]*).*//')
                if [ "$DISPLAY" != "$PHONE" ]; then
                  echo "=== $DISPLAY ==="
                  echo "    $PHONE"
                else
                  echo "=== $PHONE ==="
                fi
                echo ""
                # Sort by timestamp and display
                tail -n +2 "$f" | sort -t'|' -k1 | while IFS='|' read -r TIME DIR SOURCE TEXT; do
                  # Unescape pipes
                  TEXT=$(echo "$TEXT" | sed 's/¦/|/g')
                  TIMESTR=$(echo "$TIME" | sed 's/^[0-9]*-[0-9]*-[0-9]* //')
                  if [ "$DIR" = "<" ]; then
                    printf "[%s] < %s\n" "$TIMESTR" "$TEXT"
                  else
                    printf "[%s] > %s\n" "$TIMESTR" "$TEXT"
                  fi
                done
                exit 0
              fi
            done
            # Fallback: search by first token
            FIRST_TOKEN=$(echo "$SELECTION" | cut -d' ' -f1)
            for f in "$TMPDIR"/conv_*; do
              [ -f "$f" ] || continue
              FILE_PHONE=$(head -1 "$f" | sed 's/^PHONE://')
              if [ "$FILE_PHONE" = "$FIRST_TOKEN" ]; then
                echo "=== $FILE_PHONE ==="
                echo ""
                tail -n +2 "$f" | sort -t'|' -k1 | while IFS='|' read -r TIME DIR SOURCE TEXT; do
                  TEXT=$(echo "$TEXT" | sed 's/¦/|/g')
                  TIMESTR=$(echo "$TIME" | sed 's/^[0-9]*-[0-9]*-[0-9]* //')
                  if [ "$DIR" = "<" ]; then
                    printf "[%s] < %s\n" "$TIMESTR" "$TEXT"
                  else
                    printf "[%s] > %s\n" "$TIMESTR" "$TEXT"
                  fi
                done
                exit 0
              fi
            done
            PREVIEW
                        chmod +x "$PREVIEW_SCRIPT"

                        # Run skim with phone|display format, extract phone on selection
                        SELECTED=$(${pkgs.skim}/bin/sk \
                          --height=100% \
                          --preview="$PREVIEW_SCRIPT {} $TMPDIR" \
                          --preview-window='down:60%:wrap' \
                          --cycle \
                          --header='Enter=reply  Ctrl-N=new  Ctrl-R=refresh' \
                          --bind='ctrl-n:abort+execute(sms-compose)' \
                          --bind='ctrl-r:abort+execute(sms-list)' \
                          < "$SORTED_LIST" || true)

                        if [ -n "$SELECTED" ]; then
                          # Extract phone number (first field before |)
                          PHONE=$(echo "$SELECTED" | cut -d'|' -f1)
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
