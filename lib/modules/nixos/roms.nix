# Miyoo Mini Plus ROM and save game sync via rsync over SSH.
#
# Stores ROMs and saves under a single base path. A dedicated
# miyoo-sync system user with a restricted SSH key (rrsync forced
# command) limits access to rsync operations within that path.
#
# The Miyoo connects with a bundled static dbclient (dropbear SSH
# client) and its private key, running:
#   rsync -e "dbclient -i key" miyoo-sync@server:roms/ /mnt/SDCARD/Roms/
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.roms;
in
{
  options.lyte.roms = {
    enable = lib.mkEnableOption "Miyoo Mini ROM/save storage with SSH-based sync";

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "/storage/miyoo-mini";
      description = "Base path containing roms/ and saves/ subdirectories.";
    };

    romSyncPubKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for read-only ROM sync (restricted via rrsync).";
    };

    saveSyncPubKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for read-write save sync (restricted via rrsync).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-miyoo" = {
      "${cfg.basePath}".d = {
        mode = "0755";
        user = "miyoo-sync";
        group = "miyoo-sync";
      };
      "${cfg.basePath}/roms".d = {
        mode = "0755";
        user = "miyoo-sync";
        group = "miyoo-sync";
      };
      "${cfg.basePath}/saves".d = {
        mode = "0755";
        user = "miyoo-sync";
        group = "miyoo-sync";
      };
      "${cfg.basePath}/saves/saves".d = {
        mode = "0755";
        user = "miyoo-sync";
        group = "miyoo-sync";
      };
      "${cfg.basePath}/saves/states".d = {
        mode = "0755";
        user = "miyoo-sync";
        group = "miyoo-sync";
      };
    };

    users.groups.miyoo-sync = { };
    users.users.miyoo-sync = {
      isSystemUser = true;
      group = "miyoo-sync";
      home = cfg.basePath;
      shell = "${pkgs.bash}/bin/bash";
      openssh.authorizedKeys.keys =
        (map (
          key: ''command="${pkgs.rrsync}/bin/rrsync -ro ${cfg.basePath}/roms",restrict ${key}''
        ) cfg.romSyncPubKeys)
        ++ (map (
          key: ''command="${pkgs.rrsync}/bin/rrsync ${cfg.basePath}/saves",restrict ${key}''
        ) cfg.saveSyncPubKeys);
    };

    services.restic.commonPaths = [ "${cfg.basePath}/saves" ];
  };
}
