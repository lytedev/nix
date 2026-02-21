{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.kanidm;
  migCfg = cfg.migrations;

  hasFiles = migCfg.files != { };
  hasSecretFiles = migCfg.secretFiles != { };

  fileEntries = lib.mapAttrsToList (name: path: { inherit name path; }) migCfg.files;
  migrationDir = pkgs.linkFarm "kanidm-migrations" fileEntries;

  runtimeMigrationDir = "/run/kanidm/migrations";
  user = config.systemd.services.kanidm.serviceConfig.User or "kanidm";
  group = config.systemd.services.kanidm.serviceConfig.Group or "kanidm";
in
{
  options.services.kanidm.migrations = {
    files = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Migration HJSON files. Keys are filenames, values are store paths.";
    };

    secretFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Migration HJSON files available only at runtime.
        Keys are filenames, values are absolute paths
        (e.g. config.sops.secrets.foo.path).
      '';
    };
  };

  config = lib.mkIf (cfg.enableServer && (hasFiles || hasSecretFiles)) (
    lib.mkMerge [
      (lib.mkIf (!hasSecretFiles) {
        services.kanidm.serverSettings.migration_path = "${migrationDir}";
      })

      (lib.mkIf hasSecretFiles {
        services.kanidm.serverSettings.migration_path = runtimeMigrationDir;

        # The upstream kanidm service is heavily sandboxed with BindPaths/BindReadOnlyPaths.
        # We must explicitly expose the migration directory to the service namespace.
        systemd.services.kanidm.serviceConfig.BindReadOnlyPaths = [ runtimeMigrationDir ];

        systemd.services.kanidm-migration-setup = {
          description = "Assemble kanidm migration directory";
          wantedBy = [ "kanidm.service" ];
          before = [ "kanidm.service" ];
          after = [ "systemd-tmpfiles-setup.service" ];
          serviceConfig.Type = "oneshot";
          script =
            let
              links = lib.concatMapStringsSep "\n" (e: "ln -sf ${e.path} $dir/${e.name}") fileEntries;
              copies = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  filename: path: "install -m 0400 -o ${user} -g ${group} ${path} $dir/${filename}"
                ) migCfg.secretFiles
              );
            in
            ''
              dir=${runtimeMigrationDir}
              rm -rf "$dir"
              install -d -m 0750 -o ${user} -g ${group} "$dir"
              ${links}
              ${copies}
            '';
        };
      })
    ]
  );
}
