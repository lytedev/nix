{
  config,
  pkgs,
  lib,
  ...
}:
let
  domain = "idm.h.lyte.dev";
in
{
  imports = [
    {
      services.kanidm.package = pkgs.unstable-packages.kanidm;
    }
  ];
  config = lib.mkIf config.services.kanidm.enableClient {
    services.kanidm = {
      # enableClient = true;
      enablePam = true;
      clientSettings.uri = "https://${domain}";
      unixSettings = {
        # hsm_pin_path = "/somewhere/else";
        pam_allowed_login_groups = [ "administrators" ];
      };

    };

    services.openssh.settings = {
      PubkeyAuthentication = true;
      UsePAM = true;
      AuthorizedKeysCommand = "/usr/sbin/kanidm_ssh_authorizedkeys %u";
      AuthorizedKeysCommandUser = "nobody";
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
