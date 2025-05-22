{
  config,
  ...
}:
{
  # plausible
  services.postgresql = {
    ensureDatabases = [ "plausible" ];
    ensureUsers = [
      {
        name = "plausible";
        ensureDBOwnership = true;
      }
    ];
  };
  users.users.plausible = {
    isSystemUser = true;
    createHome = false;
    group = "plausible";
  };
  users.extraGroups = {
    "plausible" = { };
  };
  services.plausible = {
    enable = true;
    database = {
      clickhouse.setup = true;
      postgres = {
        setup = false;
        dbname = "plausible";
      };
    };
    server = {
      baseUrl = "https://a.lyte.dev";
      disableRegistration = true;
      port = 8899;
      secretKeybaseFile = config.sops.secrets.plausible-secret-key-base.path;
    };
  };
  sops.secrets = {
    plausible-secret-key-base = {
      owner = "plausible";
      group = "plausible";
    };
    plausible-admin-password = {
      owner = "plausible";
      group = "plausible";
    };
  };
  systemd.services.plausible = {
    serviceConfig.User = "plausible";
    serviceConfig.Group = "plausible";
  };
  services.caddy.virtualHosts."a.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :${toString config.services.plausible.server.port}
    '';
  };
}
