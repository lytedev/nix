{
  lib,
  config,
  pkgs,
  ...
}:
let
  # only include bitwarden-desktop on desktop systems (it's expensive to build)
  isDesktop = config.lyte.desktop.enable or false;
in
{
  config = lib.mkIf config.programs.firefox.enable {
    home = {
      sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
      };
      packages = with pkgs; [
        pywal
        pywalfox-native
      ];
    };

    programs.firefox = {
      # enable = true;
      profileVersion = null;
      package = pkgs.firefox.override {
        nativeMessagingHosts =
          with pkgs;
          lib.optionals isDesktop [
            bitwarden-desktop
            # pywalfox-native
          ];
      };
      profiles = {
        primary = {
          id = 0;
          settings = {
            "alerts.useSystemBackend" = true;
            "widget.gtk.rounded-bottom-corners.enabled" = true;
            "general.smoothScroll" = true;
            "browser.zoom.siteSpecific" = true;
          };

          extraConfig = builtins.readFile ../../../dotfiles/firefox/user.js;

          userChrome = builtins.readFile ../../../dotfiles/firefox/userChrome.css;
        };
      };
    };
  };
}
