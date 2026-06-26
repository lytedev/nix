# Surface the Miyoo Mini ROM collection inside the RetroDECK (ES-DE) library that
# syncthing replicates to the Steam Decks, WITHOUT a second managed copy of each
# game and WITHOUT library drift.
#
# How: mirror the OnionOS source into a hidden `.miyoo/` dir *inside* the synced
# `retrodeck-roms` folder, then point ES-DE system dirs at it with RELATIVE
# symlinks. Because both the mirror and the links live inside the one synced
# folder and the links are relative, they resolve identically on every peer
# (verified on the decks). The OnionOS source keeps its own folder names so the
# Miyoo device's own rsync keeps working untouched.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  miyooRomsDir = "${config.lyte.roms.basePath}/roms";
  retrodeckRomsDir = "/storage/syncthing/retrodeck/roms";
  mirrorDirName = ".miyoo";
  mirrorDir = "${retrodeckRomsDir}/${mirrorDirName}";
  syncthingUser = config.services.syncthing.user;
  syncthingGroup = config.services.syncthing.group;

  # OnionOS (Miyoo) system-folder name -> ES-DE (RetroDECK) system-folder name.
  # A system absent from this map is left un-mirrored rather than guessed wrong.
  onionToEsdeSystem = {
    ARCADE = "arcade";
    FC = "nes";
    GB = "gb";
    GBA = "gba";
    GBC = "gbc";
    GG = "gamegear";
    MD = "megadrive";
    MS = "mastersystem";
    N64 = "n64";
    NDS = "nds";
    PS = "psx";
    SFC = "snes";
  };

  # OnionOS UI artifacts that are not game roms and must not become "games".
  onionNonRomGlobs = [
    "Imgs/"
    "*.db"
    "*.json"
    "*.txt"
    "*.xml"
    "*.miyoocmd"
    "~*"
    ".*"
  ];

  rsyncExcludeFlags = lib.concatMapStringsSep " " (
    g: "--exclude=${lib.escapeShellArg g}"
  ) onionNonRomGlobs;
  esdeSystemCaseArms = lib.concatStringsSep "\n      " (
    lib.mapAttrsToList (onion: esde: "${onion}) echo ${lib.escapeShellArg esde} ;;") onionToEsdeSystem
  );
  miyooSymlinkPrefix = "../${mirrorDirName}/";
in
{
  systemd.services.miyoo-retrodeck-mirror = {
    description = "Mirror Miyoo Mini roms into the RetroDECK collection (name-mapped, relative-symlinked)";
    after = [ "syncthing.service" ];
    path = [
      pkgs.rsync
      pkgs.coreutils
      pkgs.findutils
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      esde_system_for() {
        case "$1" in
        ${esdeSystemCaseArms}
        *) echo "" ;;
        esac
      }

      mkdir -p ${lib.escapeShellArg mirrorDir}
      rsync -a --delete-excluded ${rsyncExcludeFlags} \
        ${lib.escapeShellArg "${miyooRomsDir}/"} ${lib.escapeShellArg "${mirrorDir}/"}

      for onion_dir in ${lib.escapeShellArg mirrorDir}/*/; do
        [ -d "$onion_dir" ] || continue
        onion="$(basename "$onion_dir")"
        esde="$(esde_system_for "$onion")"
        [ -n "$esde" ] || continue

        system_dir="${retrodeckRomsDir}/$esde"
        mkdir -p "$system_dir"
        # Drop our previously-created links so removed Miyoo roms don't linger.
        find "$system_dir" -maxdepth 1 -type l -lname ${lib.escapeShellArg "${miyooSymlinkPrefix}*"} -delete

        for rom in "$onion_dir"*; do
          [ -f "$rom" ] || continue
          name="$(basename "$rom")"
          target="$system_dir/$name"
          # Never clobber a real game that already exists under this system.
          if [ -e "$target" ] && [ ! -L "$target" ]; then continue; fi
          ln -sfn "${miyooSymlinkPrefix}$onion/$name" "$target"
        done
      done

      chown -R ${syncthingUser}:${syncthingGroup} ${lib.escapeShellArg mirrorDir}
      for esde in ${lib.concatStringsSep " " (lib.attrValues onionToEsdeSystem)}; do
        find "${retrodeckRomsDir}/$esde" -maxdepth 1 -type l -lname ${lib.escapeShellArg "${miyooSymlinkPrefix}*"} \
          -exec chown -h ${syncthingUser}:${syncthingGroup} {} + 2>/dev/null || true
      done
    '';
  };

  systemd.timers.miyoo-retrodeck-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };
}
