{pkgs, ...}: {
  # this is really just for development usage
  services.postgresql = {
    enable = true;
    ensureDatabases = ["daniel"];
    ensureUsers = [
      {
        name = "daniel";
        ensureDBOwnership = true;
      }
    ];
    # enableTCPIP = true;

    package = pkgs.postgresql_15;

    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser    auth-method
      local all       postgres  peer map=superuser_map
      local all       daniel    peer map=superuser_map
      local sameuser  all       peer map=superuser_map

      # lan ipv4
      host  all       all     10.0.0.0/24   trust
      host  all       all     127.0.0.1/32  trust

      # tailnet ipv4
      host       all       all     100.64.0.0/10 trust
    '';

    identMap = ''
      # ArbitraryMapName systemUser DBUser
      superuser_map    root       postgres
      superuser_map    postgres   postgres
      superuser_map    daniel     postgres

      # Let other names login as themselves
      superuser_map   /^(.*)$    \1
    '';
  };

  environment.systemPackages = with pkgs; [
    pgcli
  ];
}
