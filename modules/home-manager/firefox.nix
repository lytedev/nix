{pkgs, ...}: {
  programs.firefox = {
    # TODO: this should be able to work on macos, no?
    # TODO: enable dark theme by default
    enable = true;

    # TODO: uses nixpkgs.pass so pass otp doesn't work
    package = pkgs.firefox.override {extraNativeMessagingHosts = [pkgs.passff-host];};

    # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
    #   ublock-origin
    # ]; # TODO: would be nice to have _all_ my firefox stuff managed here instead of Firefox Sync maybe?

    profiles = {
      daniel = {
        id = 0;
        settings = {
          "general.smoothScroll" = true;
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

          #webrtcIndicator {
            display: none;
          }

          #main-window[tabsintitlebar="
          true "]:not([extradragspace="
          true "]) #TabsToolbar>.toolbar-items {
            opacity: 0;
            pointer-events: none;
          }

          #main-window:not([tabsintitlebar="
          true "]) #TabsToolbar {
            visibility: collapse !important;
          }
        '';

        # userContent = ''
        # '';
      };
    };
  };
}