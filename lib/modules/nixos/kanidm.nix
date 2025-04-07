{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.services.kanidm.enableClient {
    services.kanidm = {
      # enableClient = true;
      enablePam = true;
      package = pkgs.unstable-packages.kanidm;

      clientSettings.uri = "https://idm.h.lyte.dev";
      unixSettings = {
        # hsm_pin_path = "/somewhere/else";
        pam_allowed_login_groups = [ ];
      };
    };
    systemd.tmpfiles.rules = [
      "d /etc/kanidm 1755 nobody users -"
    ];

    # module has the incorrect file permissions out of the box
    environment.etc = {
      # "kanidm" = {
      #   enable = true;
      #   user = "nobody";
      #   group = "users";
      #   mode = "0755";
      # };
      "kanidm/unixd" = {
        user = "kanidm-unixd";
        group = "kanidm-unixd";
        mode = "0700";
      };
      "kanidm/config" = {
        user = "nobody";
        group = "users";
        mode = "0755";
      };
    };
  };
}
