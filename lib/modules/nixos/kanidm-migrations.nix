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
          # RemainAfterExit keeps the oneshot "active" so a nixos switch
          # restarts (re-runs) it when the migration content changes —
          # without it the unit is dead after boot and deploys silently
          # leave stale files in /run until the next kanidm restart.
          serviceConfig.Type = "oneshot";
          serviceConfig.RemainAfterExit = true;
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

              # Migrations only apply at kanidmd startup or via an explicit
              # admin-socket reload. When this unit re-runs on a nixos switch
              # (migration content changed) and kanidm is already up, trigger
              # a live re-apply so changes don't silently wait for the next
              # restart/reboot.
              if systemctl is-active --quiet kanidm.service; then
                echo "kanidm running; triggering live migration reload"
                ${cfg.package}/bin/kanidmd scripting reload || \
                  echo "WARNING: live reload failed; migrations will apply on next kanidm restart" >&2
              fi
            '';
        };
      })
    ]
  );
}
