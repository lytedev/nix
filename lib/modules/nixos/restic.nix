{
  lib,
  # options,
  # config,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.services.restic.commonPaths = mkOption {
    type = types.nullOr (types.listOf types.str);
    default = [ ];
    description = ''
      Which paths to backup, in addition to ones specified via
      `dynamicFilesFrom`.  If null or an empty array and
      `dynamicFilesFrom` is also null, no backup command will be run.
       This can be used to create a prune-only job.
    '';
    example = [
      "/var/lib/postgresql"
      "/home/user/backup"
    ];
  };
}
