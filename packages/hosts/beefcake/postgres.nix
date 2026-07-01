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

    # TCP is needed (the `happy` container connects over 127.0.0.1:5432 — it runs
    # with --network=host, so "localhost" is the host loopback), but bind to
    # loopback ONLY, not 0.0.0.0. `enableTCPIP = true` would set
    # listen_addresses = "*"; nothing authorized reaches postgres over a
    # non-loopback address (pg_hba trusts only 127.0.0.1/32 and ::1/128, and the
    # firewall doesn't open 5432), so the 0.0.0.0 bind was pure latent exposure —
    # one firewall regression from being reachable on the LAN/tailnet.
    #
    # FUTURE (podman->k8s migration): a pod that needs postgres arrives over the
    # flannel bridge (cni0, 10.42.0.1 / pod CIDR 10.42.0.0/16), NOT loopback. When
    # that happens, add the bridge IP here (e.g. "localhost,10.42.0.1") AND a
    # scoped pg_hba line for 10.42.0.0/16 — do not go back to "*". See
    # lib/doc/podman-to-k8s-migration.md.
    #
    # "localhost" (not "127.0.0.1") so BOTH loopback families are bound — happy's
    # DATABASE_URL uses the hostname "localhost", which Node may resolve to ::1.
    enableTCPIP = false;
    settings.listen_addresses = lib.mkForce "localhost";

    package = lib.mkForce pkgs.postgresql_17;

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
