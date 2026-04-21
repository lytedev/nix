{
  config,
  pkgs,
  lib,
  options,
  ...
}:
let
  domain = "idm.h.lyte.dev";
  # nixpkgs-unstable (Feb 2026+) restructured kanidm options:
  # unixSettings → unix.settings, pam_allowed_login_groups → kanidm.pam_allowed_login_groups
  hasNewKanidmModule = options.services.kanidm ? unix;
  isClientEnabled =
    if hasNewKanidmModule then
      config.services.kanidm.client.enable
    else
      config.services.kanidm.enableClient;
in
{
  imports = [
    {
      services.kanidm.package = pkgs.kanidm;
    }
  ];
  config = lib.mkIf isClientEnabled {
    services.kanidm = {
      enablePam = true;
      clientSettings.uri = "https://${domain}";
      unixSettings =
        if hasNewKanidmModule then
          {
            # Identity is local (users.users.daniel); kanidm-unixd
            # handles the administrators-group sudo check and nothing
            # else. Leaving uid/gid/home/shell at their SPN-form
            # defaults means shortname `daniel` isn't claimed by
            # kanidm and falls through to /etc/passwd.
            kanidm.pam_allowed_login_groups = [ "administrators" ];
          }
        else
          {
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
