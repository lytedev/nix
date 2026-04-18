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
            # Kanidm 1.10+ unixd v2 defaults uid/gid resolution to SPN
            # form (name@domain). Force shortname so `daniel` resolves
            # to the kanidm user (no local fallback needed).
            uid_attr_map = "name";
            gid_attr_map = "name";
            # Report pw_dir as /home/<name> so kanidm agrees with
            # the flat home layout our tmpfiles rule creates.
            home_attr = "name";
            home_alias = "none";
            # Kanidm doesn't set a per-user shell by default. Without
            # a local users.users declaration, we need to tell unixd
            # what shell to hand out for login sessions.
            default_shell = "${pkgs.fish}/bin/fish";
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
