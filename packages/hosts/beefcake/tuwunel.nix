{ config, lib, ... }:
let
  port = 6167;
  dataDir = "/storage/tuwunel";
  backupDir = "/storage/tuwunel-backups";
in
{
  systemd.tmpfiles.settings."10-tuwunel" = {
    "${dataDir}" = {
      d = {
        user = "tuwunel";
        group = "tuwunel";
        mode = "0700";
      };
    };
    "${backupDir}" = {
      d = {
        user = "tuwunel";
        group = "tuwunel";
        mode = "0700";
      };
    };
  };

  services.restic.commonPaths = [ backupDir ];

  sops.secrets.matrix-oauth-client-secret = { };

  sops.templates."tuwunel.toml" = {
    owner = "tuwunel";
    content = ''
      [global]
      server_name = "lyte.dev"
      database_path = "${dataDir}/"
      database_backup_path = "${backupDir}/"
      database_backups_to_keep = 2
      admin_execute = ["server backup-database"]
      admin_signal_execute = ["server backup-database"]
      port = [${toString port}]
      allow_federation = false
      allow_registration = false
      sso_default_provider_id = "matrix.lyte.dev"

      [global.well_known]
      client = "https://matrix.lyte.dev/"

      [[global.identity_provider]]
      brand = "idm.h.lyte.dev"
      client_id = "matrix.lyte.dev"
      client_secret = "${config.sops.placeholder.matrix-oauth-client-secret}"
      callback_url = "https://matrix.lyte.dev/_matrix/client/unstable/login/sso/callback/matrix.lyte.dev"
      issuer_url = "https://idm.h.lyte.dev/oauth2/openid/matrix.lyte.dev"
      discovery_url = "https://idm.h.lyte.dev/oauth2/openid/matrix.lyte.dev/.well-known/openid-configuration"
      scope = ["openid", "profile", "email"]
      userid_claims = ["preferred_username", "name"]
    '';
  };

  services.matrix-tuwunel = {
    enable = true;
    settings = {
      global = {
        server_name = "lyte.dev";
        port = [ port ];
        allow_federation = false;
        allow_registration = false;
      };
    };
  };

  systemd.services.tuwunel.environment.TUWUNEL_CONFIG =
    lib.mkForce
      config.sops.templates."tuwunel.toml".path;
  systemd.services.tuwunel.serviceConfig.ReadWritePaths = [
    dataDir
    backupDir
  ];

  # Trigger a RocksDB online backup before restic runs by sending SIGUSR2,
  # which tuwunel handles via admin_signal_execute = ["server backup-database"]
  systemd.services.tuwunel-backup = {
    description = "Trigger tuwunel RocksDB online backup";
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe' config.systemd.package "systemctl"} kill --signal=USR2 tuwunel.service
      # give tuwunel time to flush and write the backup
      sleep 10
    '';
  };
  systemd.timers.tuwunel-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = [
        "04:30"
        "17:30"
      ];
    };
  };

  # Caddy reverse proxy
  services.caddy.virtualHosts."matrix.lyte.dev".extraConfig = ''
    reverse_proxy /_matrix/* :${toString port}
    reverse_proxy /_synapse/client/* :${toString port}
    reverse_proxy /_tuwunel/oidc/* :${toString port}
    reverse_proxy /.well-known/openid-configuration :${toString port}
  '';

  services.caddy.virtualHosts."http://matrix.lyte.dev:8448".extraConfig = ''
    reverse_proxy /_matrix/* :${toString port}
  '';
}
