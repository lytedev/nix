{ pkgs, config, ... }:
{
  services.factorio = {
    enable = false;
    package = pkgs.factorio-headless.override {
      versionsJson = ./factorio-versions.json;
    };
    admins = [ "lytedev" ];
    autosave-interval = 5;
    game-name = "Flanwheel Online";
    description = "Space Age 2.0";
    openFirewall = true;
    lan = true;
    # public = true; # NOTE: cannot be true if requireUserVerification is false
    port = 34197;
    requireUserVerification = false; # critical for DRM-free users

    # contains the game password and account password for "public" servers
    extraSettingsFile = config.sops.secrets.factorio-server-settings.path;
  };
  sops.secrets = {
    factorio-server-settings = {
      mode = "0777";
    };
  };
}
