{ pkgs, ... }:
{
  home = {
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };

  programs.firefox = {
    enable = true;
    profileVersion = null;
    package = pkgs.firefox.override {
      nativeMessagingHosts = with pkgs; [ bitwarden ];
    };
    /*
      TODO: this should be able to work on macos, no?
      TODO: enable color scheme/theme by default
    */
    profiles = {
      daniel = {
        id = 0;
        settings = {
          "alerts.useSystemBackend" = true;
          "widget.gtk.rounded-bottom-corners.enabled" = true;
          "general.smoothScroll" = true;
          "browser.zoom.siteSpecific" = true;
        };

        extraConfig = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          // user_pref("full-screen-api.ignore-widgets", true);
          user_pref("media.ffmpeg.vaapi.enabled", true);
          user_pref("media.rdd-vpx.enabled", true);
        '';

        userChrome = ''
          #TabsToolbar {
            visibility: collapse;
          }

          #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar>.toolbar-items {
            opacity: 0;
            pointer-events: none;
          }

          #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
            visibility: collapse !important;
          }

          #webrtcIndicator {
            display: none;
          }
        '';

        /*
          userContent = ''
          '';
        */
      };
    };
  };
}
