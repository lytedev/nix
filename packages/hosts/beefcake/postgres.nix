{ lib, pkgs, ... }:
{
  systemd.tmpfiles.settings = {
    "10-postgres" = {
      "/storage/postgres" = {
        "d" = {
          mode = "0750";
          user = "postgres";
          group = "postgres";
        };
      };
    };
  };
  services.postgresql = {
    enable = true;
    dataDir = "/storage/postgres";
    enableTCPIP = true;

    package = lib.mkForce pkgs.postgresql_15;

    # https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
    # TODO: give the "daniel" user access to all databases
    /*
      authentication = pkgs.lib.mkOverride 10 ''
        #type database  user      auth-method    auth-options
        local all       postgres  peer           map=superuser_map
        local all       daniel    peer           map=superuser_map
        local sameuser  all       peer           map=superuser_map

        # lan ipv4
        host  all       daniel    192.168.0.0/16 trust
        host  all       daniel    10.0.0.0/24    trust

        # tailnet ipv4
        host  all       daniel    100.64.0.0/10 trust
      '';
    */

    /*
      identMap = ''
        # map            system_user db_user
        superuser_map    root        postgres
        superuser_map    postgres    postgres
        superuser_map    daniel      postgres

        # Let other names login as themselves
        superuser_map    /^(.*)$     \1
      '';
    */
  };

  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    compression = "none"; # hoping for restic deduplication here?
    location = "/storage/postgres-backups";
    startAt = "*-*-* 03:00:00";
  };
  services.restic.commonPaths = [
    "/storage/postgres-backups"
  ];
}
