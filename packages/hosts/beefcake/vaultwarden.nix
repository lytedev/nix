{ config, ... }:
{
  services.restic.commonPaths = [
    config.services.vaultwarden.backupDir
  ];
  services.vaultwarden = {
    enable = true;
    backupDir = "/storage/vaultwarden/backups";
    config = {
      DOMAIN = "https://bw.lyte.dev";
      SIGNUPS_ALLOWED = "false";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      /*
        TODO: smtp setup?
        right now, I think I configured this manually by temporarily setting ADMIN_TOKEN
        and then configuring in https://bw.lyte.dev/admin
      */
    };
  };
  services.caddy.virtualHosts."bw.lyte.dev" = {
    extraConfig = ''reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT}'';
  };
}
