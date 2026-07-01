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
      # Holds the Factorio account + game passwords (see extraSettingsFile
      # above), so it must not be world-readable. Root-only.
      #
      # NOTE: the factorio unit runs with `DynamicUser = true`, so there is
      # no static `factorio` user/group at sops activation time to own this
      # secret (a transient DynamicUser identity does not exist in NSS when
      # sops chowns secrets early in activation). When re-enabling the
      # service, grant read access via a shared supplementary group
      # (secret `group` + `SupplementaryGroups` on the unit) rather than
      # loosening the mode.
      mode = "0400";
    };
  };
}
