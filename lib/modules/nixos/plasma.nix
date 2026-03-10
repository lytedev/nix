{
  pkgs,
  lib,
  config,
  options,
  ...
}:
let
  hasPlasmaLoginManager = options.services.displayManager ? plasma-login-manager;
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
      xdg.portal.extraPortals = with pkgs.kdePackages; [ xdg-desktop-portal-kde ];

      programs.kdeconnect.enable = true;
      networking.firewall = rec {
        allowedTCPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
        allowedUDPPortRanges = allowedTCPPortRanges;
      };

      services.xserver.enable = true;

      services.desktopManager.plasma6.enable = true;
      programs.dconf.enable = true;

      # Enable virtual keyboard (plasma-keyboard) in KWin
      # plasma-keyboard is KDE's native Qt6 virtual keyboard for Plasma 6.
      # It wraps qtvirtualkeyboard and speaks the Wayland input-method protocol.
      # KWin's KCM discovers it via X-KDE-Wayland-VirtualKeyboard=true in its .desktop file.
      # The kwinrc InputMethod key must point to the .desktop file path.
      # KDE global defaults: Ayu Dark color scheme, ghostty terminal, theme settings
      # Full file in dotfiles/plasma/kdeglobals; delivered via /etc/xdg/ so KDE
      # reads it as a default without symlinking into the repo.
      environment.etc."xdg/kdeglobals".text = lib.mkDefault (
        builtins.readFile ../../../dotfiles/plasma/kdeglobals
      );

      # Global keyboard shortcuts (vim-style window nav, desktop switching, etc.)
      environment.etc."xdg/kglobalshortcutsrc".text = lib.mkDefault (
        builtins.readFile ../../../dotfiles/plasma/kglobalshortcutsrc
      );

      # Session management: restore previous session on login
      environment.etc."xdg/ksmserverrc".text = lib.mkDefault (
        builtins.readFile ../../../dotfiles/plasma/ksmserverrc
      );

      # Notification defaults: popup position, seen apps
      environment.etc."xdg/plasmanotifyrc".text = lib.mkDefault (
        builtins.readFile ../../../dotfiles/plasma/plasmanotifyrc
      );

      # Default MIME type associations (Helix for text, Ark for archives, etc.)
      environment.etc."xdg/mimeapps.list".text = lib.mkDefault (
        builtins.readFile ../../../dotfiles/plasma/mimeapps.list
      );

      # Disable Baloo file indexing (filename and content search)
      environment.etc."xdg/baloofilerc".text = lib.mkDefault ''
        [Basic Settings]
        Indexing-Enabled=false
      '';

      # Window rules: no titlebar/frame for Ghostty
      environment.etc."xdg/kwinrulesrc".text = lib.mkDefault ''
        [1]
        Description=Ghostty no titlebar
        noborder=true
        noborderrule=2
        wmclass=com.mitchellh.ghostty
        wmclasscomplete=false
        wmclassmatch=1

        [General]
        count=1
        rules=1
      '';

      # Common plasma desktop defaults (clock, launcher, pager, taskbar)
      # These act as XDG defaults — Plasma will use them for new profiles
      # but per-host layout (screens, panels, containments) is managed by Plasma itself
      environment.etc."xdg/plasma-org.kde.plasma.desktop-appletsrc".text = lib.mkDefault ''
        [Containments][2][General]
        thickness=32

        [Containments][2][Applets][21][Configuration][Appearance]
        dateFormat=isoDate
        showDate=true
        dateDisplayFormat=adaptiveLocaleShort
        fontWeight=400
        use24hFormat=2

        [Containments][2][Applets][3][Configuration][General]
        icon=nix-snowflake
        systemFavorites=suspend\\,hibernate\\,reboot\\,shutdown

        [Containments][2][Applets][4][Configuration][General]
        showOnlyCurrentScreen=true
        wrapPage=true

        [Containments][2][Applets][5][Configuration][General]
        launchers=applications:com.mitchellh.ghostty.desktop,preferred://browser,applications:systemsettings.desktop,preferred://filemanager

        [Containments][2][Applets][7][General]
        extraItems=org.kde.kdeconnect,org.kde.plasma.cameraindicator,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.notifications,org.kde.kscreen,org.kde.plasma.battery,org.kde.plasma.bluetooth,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.printmanager,org.kde.plasma.volume,org.kde.plasma.weather,org.kde.plasma.clipboard
        knownItems=org.kde.kdeconnect,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.notifications,org.kde.kscreen,org.kde.plasma.battery,org.kde.plasma.bluetooth,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.printmanager,org.kde.plasma.volume,org.kde.plasma.weather
        hiddenItems=org.kde.plasma.clipboard

        [Containments][2][Applets][7][Applets][20][Configuration][WeatherStation]
        placeDisplayName=Overland Park, Kansas, US
        placeInfo=place|Overland Park, Kansas, US|extra|US0KS0455;Overland Park
        provider=wettercom
      '';

      # Keyboard repeat and numlock defaults
      environment.etc."xdg/kcminputrc".text = lib.mkDefault ''
        [Keyboard]
        NumLock=0
        RepeatDelay=200
        RepeatRate=80
      '';

      # Apply touchpad settings to all touchpad devices via KWin DBus at login.
      # The old [Touchpad] section in kcminputrc only works on X11; on Plasma 6
      # Wayland, KWin requires per-device config sections. This script applies
      # settings generically to any touchpad without knowing vendor/product IDs.
      lyte.userFiles.".config/autostart/plasma-touchpad-defaults.desktop" = ''
        [Desktop Entry]
        Type=Application
        Name=Touchpad Defaults
        Exec=${pkgs.writeShellScript "plasma-touchpad-defaults" ''
          sleep 2
          for dev in /org/kde/KWin/InputDevice/*; do
            sysname="''${dev##*/}"
            is_touchpad=$(dbus-send --session --dest=org.kde.KWin --type=method_call \
              --print-reply "$dev" org.freedesktop.DBus.Properties.Get \
              string:org.kde.KWin.InputDevice string:touchpad 2>/dev/null \
              | grep -o 'boolean true' || true)
            if [ -n "$is_touchpad" ]; then
              dbus-send --session --dest=org.kde.KWin --type=method_call \
                "$dev" org.freedesktop.DBus.Properties.Set \
                string:org.kde.KWin.InputDevice string:naturalScroll variant:boolean:true
              dbus-send --session --dest=org.kde.KWin --type=method_call \
                "$dev" org.freedesktop.DBus.Properties.Set \
                string:org.kde.KWin.InputDevice string:tapToClick variant:boolean:true
              dbus-send --session --dest=org.kde.KWin --type=method_call \
                "$dev" org.freedesktop.DBus.Properties.Set \
                string:org.kde.KWin.InputDevice string:disableWhileTyping variant:boolean:false
            fi
          done
        ''}
        X-KDE-autostart-phase=2
      '';

      # Screen lock after 10 minutes, DPMS standby after 15 minutes
      environment.etc."xdg/kscreenlockerrc".text = lib.mkDefault ''
        [Daemon]
        Autolock=true
        Timeout=10
        LockOnResume=true
      '';

      environment.etc."xdg/powermanagementprofilesrc".text = lib.mkDefault ''
        [AC][DPMSControl]
        idleTime=900
        lockBeforeTurnOff=0

        [Battery][DPMSControl]
        idleTime=600
        lockBeforeTurnOff=0
      '';

      # Electron/Chromium native Wayland support
      environment.sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        NIXOS_OZONE_WL = "1";
      };

      environment.etc."xdg/kwinrc".text = lib.mkDefault ''
        [Wayland]
        InputMethod=${pkgs.kdePackages.plasma-keyboard}/share/applications/org.kde.plasma.keyboard.desktop
        VirtualKeyboardEnabled=true

        [NightColor]
        Active=true
        NightTemperature=3000

        [Desktops]
        Number=4
        Rows=1

        [Compositing]
        AllowTearing=true

        [MouseBindings]
        CommandAll1=Move
        CommandAll2=Toggle raise and lower
        CommandAll3=Resize

        [Plugins]
        hidecursorEnabled=true
      '';

      # services.xrdp.enable = false;
      # services.xrdp.defaultWindowManager = "plasma";
      # services.xrdp.openFirewall = false;

      # Merge /etc/xdg/kglobalshortcutsrc overrides into the user's file and
      # apply them live via D-Bus.  Plasma rewrites ~/.config/kglobalshortcutsrc
      # on every logout, permanently shadowing /etc/xdg/ defaults once a user
      # file exists.  Run this command manually after a rebuild to push shortcut
      # changes.  The script both patches the config file (so Plasma persists
      # the values on next logout) and calls setForeignShortcutKeys on KWin's
      # kglobalaccel D-Bus interface (so shortcuts take effect immediately
      # without logging out).
      environment.systemPackages = with pkgs; [
        (writeShellScriptBin "plasma-sync-shortcuts" ''
          set -euo pipefail
          src="/etc/xdg/kglobalshortcutsrc"
          dst="''${XDG_CONFIG_HOME:-$HOME/.config}/kglobalshortcutsrc"

          if [ ! -f "$src" ]; then
            echo "No override file at $src" >&2
            exit 1
          fi

          if [ ! -f "$dst" ]; then
            echo "No user file at $dst — /etc/xdg/ defaults will apply automatically"
            exit 0
          fi

          cp "$dst" "$dst.bak"
          echo "Backed up $dst to $dst.bak"

          # Phase 1: Patch the config file so Plasma persists values on logout.
          # Uses awk with ENVIRON to preserve KDE's literal \t shortcut
          # separators (awk -v would interpret \t as tab).  Handles KDE's
          # nested [section][subsection] INI syntax that crudini cannot parse.
          group=""
          while IFS="" read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            if [[ "$line" =~ ^\[(.+)\]$ ]]; then
              group="''${BASH_REMATCH[1]}"
              if ! grep -qxF "[$group]" "$dst"; then
                printf '\n[%s]\n' "$group" >> "$dst"
                echo "  Added new group [$group]"
              fi
              continue
            fi
            key="''${line%%=*}"
            value="''${line#*=}"
            [ -z "$group" ] && continue
            _AWK_GROUP="[$group]" _AWK_KEY="$key" _AWK_VALUE="$value" \
            ${pkgs.gawk}/bin/awk '
              BEGIN { group=ENVIRON["_AWK_GROUP"]; key=ENVIRON["_AWK_KEY"]; value=ENVIRON["_AWK_VALUE"]; found_group=0; replaced=0 }
              $0 == group { found_group=1; print; next }
              /^\[/ { if (found_group && !replaced) { print key "=" value; replaced=1 }; found_group=0 }
              found_group && index($0, key "=") == 1 { print key "=" value; replaced=1; next }
              { print }
              END { if (found_group && !replaced) print key "=" value }
            ' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
            echo "  [$group] $key"
          done < "$src"
          echo "Config file updated."

          # Phase 2: Apply shortcuts live via D-Bus so they take effect
          # immediately without logging out.  Uses busctl to call
          # setForeignShortcutKeys on KWin's embedded kglobalaccel.
          # Key strings are converted to Qt key codes via PyQt6's
          # QKeySequence.fromString(), so any key Qt recognises works
          # without maintaining a manual lookup table.
          echo "Applying shortcuts live via D-Bus..."
          ${
            (pkgs.python3.withPackages (p: [ p.pyqt6 ]))
          }/bin/python3 ${pkgs.writeText "plasma-apply-shortcuts.py" ''
            import subprocess, sys, os, re
            from PyQt6.QtGui import QKeySequence

            def shortcut_to_qtkey(s):
                """Convert a shortcut string like 'Meta+K' to a Qt key code int."""
                ks = QKeySequence.fromString(s.strip())
                if ks.count() == 0:
                    return None
                return ks[0].toCombined()

            def apply_shortcut(component, action, friendly_comp, friendly_action, key_codes):
                """Call setForeignShortcutKeys via busctl."""
                n = len(key_codes)
                cmd = [
                    "busctl", "--user", "call",
                    "org.kde.kglobalaccel", "/kglobalaccel",
                    "org.kde.KGlobalAccel", "setForeignShortcutKeys",
                    "asa(ai)",
                    "4", component, action, friendly_comp, friendly_action,
                    str(n),
                ]
                for kc in key_codes:
                    cmd.extend(["4", str(kc), "0", "0", "0"])
                subprocess.run(cmd, check=True)

            def parse_config(path):
                """Parse kglobalshortcutsrc into a list of shortcut entries."""
                entries = []
                group = ""
                friendly_name = ""
                with open(path) as f:
                    for line in f:
                        line = line.rstrip("\n")
                        if not line:
                            continue
                        m = re.match(r"^\[(.+)\]$", line)
                        if m:
                            group = m.group(1)
                            friendly_name = ""
                            continue
                        if "=" not in line or not group:
                            continue
                        key, value = line.split("=", 1)
                        if key == "_k_friendly_name":
                            friendly_name = value
                            continue
                        # value format: "shortcut(s),default(s),description"
                        parts = value.split(",")
                        if len(parts) < 3:
                            continue
                        shortcuts_str = parts[0]
                        description = ",".join(parts[2:])
                        # Multiple shortcuts are separated by literal \t in the file
                        shortcut_strs = shortcuts_str.split("\\t")
                        key_codes = []
                        ok = True
                        for ss in shortcut_strs:
                            ss = ss.strip()
                            if not ss or ss == "none":
                                continue
                            kc = shortcut_to_qtkey(ss)
                            if kc is None:
                                print(f"  SKIP [{group}] {key}: unknown key in '{ss}'")
                                ok = False
                                break
                            key_codes.append(kc)
                        if not ok or not key_codes:
                            continue
                        fn = friendly_name or group
                        entries.append((group, key, fn, description.strip() or key, key_codes))
                return entries

            src = os.environ.get("SYNC_SRC", "/etc/xdg/kglobalshortcutsrc")
            entries = parse_config(src)

            # Apply in two passes.  On the first pass, shortcuts that reuse a
            # key previously claimed by another action may silently fail (the
            # daemon rejects the new binding while the old owner still holds
            # it).  The first pass frees old bindings; the second pass retries
            # any that ended up empty.
            for pass_num in (1, 2):
                for component, action, friendly_comp, description, key_codes in entries:
                    try:
                        apply_shortcut(component, action, friendly_comp, description, key_codes)
                        if pass_num == 1:
                            print(f"  OK [{component}] {action}")
                    except subprocess.CalledProcessError as e:
                        if pass_num == 2:
                            print(f"  FAIL [{component}] {action}: {e}")

            print(f"Applied {len(entries)} shortcuts")
          ''}
          echo "Done. All shortcuts are active."
        '')

        wl-clipboard
        # inkscape
        # krita
        noto-fonts
        # vlc

        kdePackages.plasma-keyboard
        kdePackages.qtvirtualkeyboard

        # kdePackages.kate
        # kdePackages.kcalc
        # kdePackages.filelight
        # kdePackages.krdc
        # kdePackages.krfb
        # kdePackages.kclock
        # kdePackages.kweather
        # kdePackages.ktorrent
        # kdePackages.kdeplasma-addons

        # unstable-packages.kdePackages.krdp

        /*
          kdePackages.kdenlive
          kdePackages.merkuro
          kdePackages.neochat
          kdePackages.kdevelop
          kdePackages.kdialog
        */
      ];

      programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;

      # Color scheme files are read-only (KDE never writes to them), so symlinks are safe.
      # All writable plasma configs are delivered via /etc/xdg/ above instead.
      lyte.userSymlinks = {
        ".local/share/color-schemes/AyuDark.colors" = "${config.lyte.dotfilesPath}/plasma/AyuDark.colors";
        ".local/share/color-schemes/AyuLight.colors" = "${config.lyte.dotfilesPath}/plasma/AyuLight.colors";
      };
    })

    (
      if hasPlasmaLoginManager then
        lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
          services.displayManager.plasma-login-manager.enable = true;
        }
      else
        lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
          services.displayManager.sddm.enable = true;
        }
    )
  ];
}
