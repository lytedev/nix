# Miyoo Mini Plus ROM and save game sync via rsync daemon.
#
# Stores ROMs and saves under a single base path and exposes two
# rsyncd modules on the LAN:
#   miyoo-roms  (read-only)  - ROM files organized by system folder
#   miyoo-saves (read-write) - RetroArch save files
#
# The Miyoo syncs via the rsync daemon protocol which requires no SSH
# client on the device -- just `rsync rsync://server/module/`.
{
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.roms;
in
{
  options.lyte.roms = {
    enable = lib.mkEnableOption "Miyoo Mini ROM/save storage with rsync daemon sync";

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "/storage/daniel/miyoo-mini";
      description = "Base path containing roms/ and saves/ subdirectories.";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "192.168.0.0/16"
        "10.0.0.0/8"
      ];
      description = "Networks allowed to connect to the rsync daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-miyoo" = {
      "${cfg.basePath}".d = {
        mode = "0755";
        user = "daniel";
        group = "users";
      };
      "${cfg.basePath}/roms".d = {
        mode = "0755";
        user = "daniel";
        group = "users";
      };
      "${cfg.basePath}/saves".d = {
        mode = "0755";
        user = "daniel";
        group = "users";
      };
    };

    services.rsyncd = {
      enable = true;
      settings = {
        global = {
          uid = "daniel";
          gid = "users";
          "use chroot" = "yes";
          "max connections" = 2;
        };
        miyoo-roms = {
          path = "${cfg.basePath}/roms";
          comment = "Miyoo Mini ROM files";
          "read only" = "yes";
          "hosts allow" = lib.concatStringsSep " " cfg.allowedNetworks;
        };
        miyoo-saves = {
          path = "${cfg.basePath}/saves";
          comment = "Miyoo Mini save files";
          "read only" = "no";
          "hosts allow" = lib.concatStringsSep " " cfg.allowedNetworks;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 873 ];

    services.restic.commonPaths = [ "${cfg.basePath}/saves" ];
  };
}
