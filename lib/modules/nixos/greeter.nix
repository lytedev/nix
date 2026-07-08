{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.desktop.greeter;

  # Greeter overhaul: replace plasma-login-manager with greetd + ReGreet, hosted
  # in a minimal niri compositor that ALSO runs wvkbd as a layer-shell on-screen
  # keyboard. plasma-login-manager has no controller-usable OSK — its keyboard is
  # touch-gated and QT_IM_MODULE can't reach the greeter's separate PAM session
  # (so only touch hosts like babyflip ever get it). niri renders layer-shell
  # reliably (the same wvkbd we already use on the desktop), so the Steam
  # Controller's lizard-mode trackpad — a real HID mouse at the greeter — can pick
  # a session and click out the password: controller-only, lid-closed login.
  # A clickable on-screen keyboard toggle for the greeter. wvkbd can't be moved at
  # runtime (its anchor is compile-time), but it hides/shows on SIGRTMIN — so a
  # small always-on-top waybar button that sends that signal lets you dismiss the
  # keyboard to see whatever it covers, then bring it back. Controller/touch-only
  # friendly (clicked with the trackpad-mouse); only the greeter needs it (the niri
  # desktop has DMS's own OSK toggle). Anchored top-right, clear of the centred
  # login form and the bottom-anchored keyboard.
  greeterWaybarConfig = pkgs.writeText "greeter-waybar.json" ''
    {
      "layer": "overlay",
      "position": "top",
      "height": 40,
      "modules-right": ["custom/keyboard", "custom/suspend", "custom/hibernate"],
      "custom/keyboard": {
        "format": "⌨",
        "tooltip": false,
        "on-click": "${pkgs.procps}/bin/pkill --signal RTMIN wvkbd-mobintl"
      },
      "custom/suspend": {
        "format": "Suspend",
        "tooltip": false,
        "on-click": "/run/current-system/sw/bin/systemctl suspend"
      },
      "custom/hibernate": {
        "format": "Hibernate",
        "tooltip": false,
        "on-click": "/run/current-system/sw/bin/systemctl hibernate"
      }
    }
  '';
  greeterWaybarStyle = pkgs.writeText "greeter-waybar.css" ''
    /* Ayu Dark */
    * {
      font-family: sans-serif;
      font-size: 18px;
      min-height: 0;
    }
    window#waybar {
      background: transparent;
    }
    #custom-keyboard,
    #custom-suspend,
    #custom-hibernate {
      background: rgba(15, 20, 25, 0.92); /* #0F1419 */
      color: #bfbdb6;
      padding: 2px 16px;
      margin: 6px 6px;
      border: 1px solid #1e232b;
      border-radius: 12px;
    }
    #custom-keyboard:hover,
    #custom-suspend:hover,
    #custom-hibernate:hover {
      background: rgba(230, 180, 80, 0.95); /* #E6B450 */
      color: #0b0e14;
      border-color: #e6b450;
    }
  '';
  greeterNiriConfig = pkgs.writeText "greeter-niri.kdl" ''
    hotkey-overlay {
        skip-at-startup
    }
    prefer-no-csd
    // VITURE Pro XR glasses: niri auto-scales them to an unusable 2.25 at the
    // greeter; pin 1.5 to match the desktop config. No-op without the glasses.
    output "PNP(CVT) VITURE 0x88888800" {
        scale 1.5
    }
    input {
        touchpad {
            tap
            natural-scroll
        }
    }
    // ReGreet does the login; wvkbd is the always-visible OSK. wvkbd is a
    // layer-shell surface, so it renders above the fullscreen greeter window and
    // stays clickable with the controller-as-mouse.
    spawn-at-startup "regreet"
    // Start hidden — the ⌨ toggle button (below) shows it on demand, keeping the
    // login form and background unobstructed by default.
    spawn-at-startup "wvkbd-mobintl" "-L" "320" "--hidden"
    // Clickable keyboard toggle (top-right); sends wvkbd its SIGRTMIN hide/show.
    spawn-at-startup "waybar" "-c" "${greeterWaybarConfig}" "-s" "${greeterWaybarStyle}"
    // Hold an idle+sleep inhibitor while the greeter is up, so laptop.nix's
    // logind IdleAction=suspend (11m) doesn't fire and drop foxtrot off the
    // network while it sits at the login screen. Released when a session starts.
    // (Lid-close still suspends by design — LidSwitchIgnoreInhibited defaults on.)
    spawn-at-startup "systemd-inhibit" "--what=idle:sleep" "--who=greeter" "--why=keep the login screen reachable" "--mode=block" "sleep" "infinity"
    window-rule {
        open-fullscreen true
    }
    binds {
        // Recovery escape hatch from a physical keyboard, if one is attached.
        Mod+Shift+E { quit skip-confirmation=true; }
    }
  '';
  greeterCommand = pkgs.writeShellScript "greeter" ''
    export PATH=${
      lib.makeBinPath [
        config.programs.niri.package
        pkgs.regreet
        pkgs.wvkbd
        pkgs.waybar
        pkgs.dbus
      ]
    }:/run/current-system/sw/bin:$PATH
    # ReGreet discovers sessions from XDG_DATA_DIRS (each dir + /wayland-sessions).
    # Point it at the display manager's sessionData so every registered
    # wayland-session (niri, plus any host-specific extras like foxtrot's
    # "Gaming (gamescope)") appears in the picker.
    export XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}
    # Disable the controlling tty's signal chars (ISIG) before launching niri. This
    # greetd session leader is root and sits in tty1's foreground process group; a
    # stray ^C on the VT reaches tty1's line discipline and the kernel SIGINTs the
    # whole group (strace: si_code=SI_KERNEL), killing this leader and bouncing back
    # to the greeter. niri takes input via libinput, never the tty, so clearing ISIG
    # is transparent. Guarded so a missing ctty is a no-op, not a launch failure.
    ${pkgs.coreutils}/bin/stty -isig < /dev/tty 2>/dev/null || true
    exec dbus-run-session niri -c ${greeterNiriConfig}
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.regreet.enable = true;
    # Dark greeter (ReGreet's GTK dark-theme preference).
    programs.regreet.settings.GTK.application_prefer_dark_theme = true;
    # Ayu Dark theme. ReGreet is plain GTK4/Adwaita (no libadwaita) and loads this
    # CSS at application priority, so override Adwaita's named colors (@define-color)
    # plus a few direct selectors for the login form.
    programs.regreet.extraCss = ''
      @define-color window_bg_color #0b0e14;
      @define-color window_fg_color #bfbdb6;
      @define-color view_bg_color #0f1419;
      @define-color view_fg_color #bfbdb6;
      @define-color card_bg_color #0f1419;
      @define-color card_fg_color #bfbdb6;
      @define-color popover_bg_color #0f1419;
      @define-color popover_fg_color #bfbdb6;
      @define-color accent_bg_color #e6b450;
      @define-color accent_fg_color #0b0e14;
      @define-color accent_color #ffb454;
      @define-color theme_bg_color #0b0e14;
      @define-color theme_fg_color #bfbdb6;
      @define-color theme_base_color #0f1419;
      @define-color theme_text_color #bfbdb6;
      @define-color theme_selected_bg_color #e6b450;
      @define-color theme_selected_fg_color #0b0e14;
      @define-color borders #1e232b;

      window, .background { background-color: #0b0e14; color: #bfbdb6; }
      label { color: #bfbdb6; }
      entry, spinbutton {
        background-color: #0f1419;
        color: #bfbdb6;
        border: 1px solid #1e232b;
        border-radius: 8px;
        padding: 8px 10px;
        caret-color: #e6b450;
      }
      entry:focus-within { border-color: #e6b450; }
      button {
        background-color: #0f1419;
        color: #bfbdb6;
        border: 1px solid #1e232b;
        border-radius: 8px;
        padding: 8px 14px;
      }
      button:hover { background-color: #151a21; border-color: #565b66; }
      button:active, button.suggested-action, button.default {
        background-color: #e6b450;
        color: #0b0e14;
        border-color: #e6b450;
      }
      button.destructive-action { color: #f07178; }
      dropdown, dropdown button, combobox button { background-color: #0f1419; color: #bfbdb6; }
      selection { background-color: #e6b450; color: #0b0e14; }
    '';
    services.greetd.settings.default_session.command = "${greeterCommand}";

    # Let the greeter user actually run the suspend/hibernate waybar buttons.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "greeter" &&
            (action.id == "org.freedesktop.login1.suspend" ||
             action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
             action.id == "org.freedesktop.login1.hibernate" ||
             action.id == "org.freedesktop.login1.hibernate-multiple-sessions")) {
          return polkit.Result.YES;
        }
      });
    '';

    # greetd is the greeter PAM service (ReGreet authenticates through it). Keep
    # it on password so a controller OSK can drive login, and so
    # pam_gnome_keyring captures the password to unlock the login keyring.
    security.pam.services.greetd.fprintAuth = false;
  };
}
