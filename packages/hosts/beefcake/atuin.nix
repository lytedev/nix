{ config, lib, ... }:

{
  users.users.atuin = {
    isSystemUser = true;
    createHome = false;
    group = "atuin";
  };
  users.extraGroups = {
    "atuin" = { };
  };
  services.postgresql = {
    ensureDatabases = [ "atuin" ];
    ensureUsers = [
      {
        name = "atuin";
        ensureDBOwnership = true;
      }
    ];
  };
  services.atuin = {
    enable = true;
    database = {
      createLocally = false;
      # NOTE: this uses postgres over the unix domain socket by default
      # uri = "postgresql://atuin@localhost:5432/atuin";
    };
    openRegistration = false;
    # TODO: would be neat to have a way to "force" a registration on the server
  };
  systemd.services.atuin = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    serviceConfig = {
      Group = "atuin";
      User = "atuin";
      # atuin 18.13 moved the server to a separate binary
      ExecStart = lib.mkForce "${lib.getExe' config.services.atuin.package "atuin-server"} start";
    };
  };
  services.caddy.virtualHosts."atuin.h.lyte.dev" = {
    extraConfig = "reverse_proxy :${toString config.services.atuin.port}";
  };
}
