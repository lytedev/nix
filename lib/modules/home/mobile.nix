{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    lyte.mobile = {
      enable = lib.mkEnableOption "Enable mobile home-manager configuration";
      useStevia = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use Stevia keyboard instead of Squeekboard";
      };
    };
  };

  config = lib.mkIf config.lyte.mobile.enable {
    # Override the default Firefox profile with mobile-friendly settings
    programs.firefox = {
      enable = true;
      profileVersion = null;
      # Override the default "primary" profile with mobile settings
      profiles.primary = lib.mkForce {
        id = 0;
        isDefault = true;
        settings = {
          # Mobile-friendly UI settings (from postmarketOS mobile-config-firefox)
          "alerts.useSystemBackend" = true;
          "browser.uidensity" = 0; # compact
          "browser.display.os-zoom-behavior" = 1;

          # Move address bar to bottom for easier thumb access
          "browser.toolbars.bookmarks.visibility" = "never";

          # Touch-friendly settings
          "apz.allow_double_tap_zooming" = true;
          "apz.allow_zooming" = true;
          "dom.w3c_touch_events.enabled" = 1;

          # Performance settings for PinePhone (no GLES3, use legacy layers)
          "layers.acceleration.force-enabled" = true;
          "gfx.webrender.force-disabled" = true; # PinePhone doesn't support GLES3

          # Privacy and mobile-friendly defaults
          "browser.startup.homepage" = "about:blank";
          "browser.newtabpage.enabled" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.zoom.siteSpecific" = true;
          "widget.gtk.rounded-bottom-corners.enabled" = true;

          # Wayland
          "widget.use-xdg-desktop-portal.file-picker" = 1;

          # Smooth scrolling
          "general.smoothScroll" = true;
        };

        extraConfig = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          user_pref("media.ffmpeg.vaapi.enabled", true);
          user_pref("media.rdd-vpx.enabled", true);
        '';

      };
    };

    # Wayland environment for Firefox
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };

    # Ghostty terminal with font
    programs.ghostty.enable = true;

    # Fonts
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      iosevkaLyteTerm
    ];

    # Dark theme for GTK apps
    gtk.theme.name = "Adwaita-dark";

    # Foot terminal with ayu dark theme
    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "IosevkaLyteTerm:size=12";
          dpi-aware = "no";
        };
        colors = {
          foreground = "e6e1cf";
          background = "0f1419";
          regular0 = "0f1419"; # black
          regular1 = "f07178"; # red
          regular2 = "b8cc52"; # green
          regular3 = "ffb454"; # yellow
          regular4 = "59c2ff"; # blue
          regular5 = "d2a6ff"; # magenta
          regular6 = "95e6cb"; # cyan
          regular7 = "e6e1cf"; # white
          bright0 = "272d38"; # bright black
          bright1 = "f07178"; # bright red
          bright2 = "b8cc52"; # bright green
          bright3 = "ffb454"; # bright yellow
          bright4 = "59c2ff"; # bright blue
          bright5 = "d2a6ff"; # bright magenta
          bright6 = "95e6cb"; # bright cyan
          bright7 = "f3f4f5"; # bright white
        };
      };
    };

    # Enable dconf for phosh/squeekboard settings
    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
        "org/gnome/desktop/a11y/applications" = {
          screen-keyboard-enabled = true;
        };
      };
    };

    # Geary mail autostart - runs as background service for notifications
    xdg.configFile."autostart/geary.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Geary
      Exec=${pkgs.geary}/bin/geary --gapplication-service
      Icon=org.gnome.Geary
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';

    # GNOME Clocks autostart - runs as background service for alarms
    xdg.configFile."autostart/gnome-clocks.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Clocks
      Exec=${pkgs.gnome-clocks}/bin/gnome-clocks --gapplication-service
      Icon=org.gnome.clocks
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';

    # Systemd user service for reliable alarm triggering
    systemd.user.services.gnome-clocks = {
      Unit = {
        Description = "GNOME Clocks alarm service";
        PartOf = [ "phosh.service" ];
        After = [ "phosh.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.gnome-clocks}/bin/gnome-clocks --gapplication-service";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "phosh.service" ];
    };

    # On-screen keyboard systemd service for phosh 0.50.0+
    # phosh OSK target wants mobi.phosh.OSK.service
    systemd.user.services."mobi.phosh.OSK" =
      if config.lyte.mobile.useStevia then
        {
          Unit = {
            Description = "Phosh On-Screen Keyboard (Stevia)";
            PartOf = [ "phosh.service" ];
            After = [ "phosh.service" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.stevia}/bin/phosh-osk-stevia";
            Restart = "on-failure";
          };
          Install = {
            WantedBy = [ "phosh.service" ];
          };
        }
      else
        {
          Unit = {
            Description = "Squeekboard on-screen keyboard";
            PartOf = [ "mobi.phosh.OSK.target" ];
          };
          Service = {
            Type = "dbus";
            BusName = "sm.puri.OSK0";
            ExecStart = "${pkgs.squeekboard}/bin/squeekboard";
            Restart = "on-failure";
          };
          Install = {
            WantedBy = [ "mobi.phosh.OSK.target" ];
          };
        };
  };
}
