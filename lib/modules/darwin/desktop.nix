# macOS desktop application config (ghostty, firefox)
#
# These apps are installed via macOS (brew/dmg), but their configs
# are managed by nix via dotfile symlinks.
{
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.desktop;
  dotfilesPath = config.lyte.dotfilesPath;
in
{
  options.lyte.desktop = {
    enable = lib.mkEnableOption "Enable desktop application configuration for macOS";
  };

  config = lib.mkIf cfg.enable {
    lyte.userSymlinks = {
      ".config/ghostty" = "${dotfilesPath}/ghostty";
      ".mozilla/firefox/primary/user.js" = "${dotfilesPath}/firefox/user.js";
      ".mozilla/firefox/primary/chrome/userChrome.css" = "${dotfilesPath}/firefox/userChrome.css";
    };

    lyte.userFiles.".mozilla/firefox/profiles.ini" = ''
      [Profile0]
      Name=primary
      IsRelative=1
      Path=primary
      Default=1

      [General]
      StartWithLastProfile=1
    '';
  };
}
