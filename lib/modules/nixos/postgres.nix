{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.services.postgresql.enable {
    # this is really just for development usage
    services.postgresql = {
      # enable = true;
      ensureDatabases = [ "daniel" ];
      ensureUsers = [
        {
          name = "daniel";
          ensureDBOwnership = true;
          ensureClauses = {
            superuser = true;
            createrole = true;
            createdb = true;
          };
        }
      ];
      # enableTCPIP = true;

      package = pkgs.postgresql_17;

      authentication = pkgs.lib.mkOverride 10 ''
        # type database  DBuser    auth-method
        local  sameuser  all       peer map=user_map
        local  all       all       peer map=superuser_map

        # localhost only
        host  all       all     127.0.0.1/32  trust
        host  all       all     ::1/128       trust
      '';

      identMap = ''
        # mapName          linuxUser  postgresUser
        superuser_map      postgres   postgres
        superuser_map      root       postgres
        superuser_map      daniel     postgres
        superuser_map      root       root
        superuser_map      daniel     daniel

        superuser_map      daniel     all

        user_map           /^(.*)$ ''\\1
      '';
    };

    environment.systemPackages = with pkgs; [
      pgcli
    ];
  };
}
