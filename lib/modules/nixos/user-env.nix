# User environment management without Home Manager
#
# Provides declarative user home directory file/symlink management,
# dconf settings, GTK/cursor theming, and Firefox profile setup
# using NixOS-native mechanisms (system.userActivationScripts).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lyte;
  danielHome = config.users.users.daniel.home;

  # Generate dconf load commands from settings attrset
  mkDconfScript =
    settings:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        path: values:
        let
          toGVariant =
            v:
            if builtins.isAttrs v && v ? _type then
              "${v._type} ${toString v.value}"
            else if builtins.isBool v then
              (if v then "true" else "false")
            else if builtins.isInt v then
              toString v
            else if builtins.isFloat v then
              toString v
            else if builtins.isString v then
              "'${v}'"
            else if builtins.isList v then
              "[${lib.concatMapStringsSep ", " toGVariant v}]"
            else
              toString v;
          kvs = lib.mapAttrsToList (k: v: "${k}=${toGVariant v}") values;
          ini = "[/]\n${lib.concatStringsSep "\n" kvs}\n";
        in
        "echo ${lib.escapeShellArg ini} | ${pkgs.dconf}/bin/dconf load /${path}/"
      ) settings
    );

  # Build the user activation script
  mkUserActivation =
    home: symlinkEntries: fileEntries: dconfEntries:
    let
      symlinkCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          target: source:
          let
            fullTarget = if lib.hasPrefix "/" target then target else "${home}/${target}";
          in
          ''
            mkdir -p "$(dirname "${fullTarget}")"
            if [ "$(readlink -f "${fullTarget}")" != "$(readlink -f "${source}")" ]; then
              ln -sfT "${source}" "${fullTarget}"
            fi
          ''
        ) symlinkEntries
      );

      fileCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          target: storePath:
          let
            fullTarget = if lib.hasPrefix "/" target then target else "${home}/${target}";
          in
          ''
            mkdir -p "$(dirname "${fullTarget}")"
            install -m 644 "${storePath}" "${fullTarget}"
          ''
        ) fileEntries
      );
    in
    pkgs.writeShellScript "lyte-user-env-activate" (
      ''
        set -euo pipefail
      ''
      + (lib.optionalString (symlinkEntries != { }) ("\n# Symlinks\n" + symlinkCmds))
      + (lib.optionalString (fileEntries != { }) ("\n# Written files\n" + fileCmds))
      + (lib.optionalString (dconfEntries != { }) ("\n# dconf settings\n" + mkDconfScript dconfEntries))
    );

  # Convert userFiles (string content) to nix store paths for safe copying
  resolvedUserFiles = lib.mapAttrs (
    name: content: pkgs.writeText (builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name) content
  ) cfg.userFiles;

  danielScript = mkUserActivation danielHome cfg.userSymlinks resolvedUserFiles cfg.dconfSettings;
in
{
  options.lyte = {
    editableConfigFiles = lib.mkEnableOption "Use live flakePath symlinks instead of nix store paths (requires flakePath to be set)";

    flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the nix flake source directory, used for dotfile symlinks when editableConfigFiles is enabled";
    };

    flakeStorePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Nix store path of the flake source (set automatically by default-module.nix)";
    };

    resolvedFlakePath = lib.mkOption {
      type = lib.types.str;
      default = if cfg.editableConfigFiles then cfg.flakePath else cfg.flakeStorePath;
      description = "Resolved flake path: live flakePath when editableConfigFiles is true, store path otherwise";
      readOnly = true;
    };

    dotfilesPath = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.resolvedFlakePath}/dotfiles";
      description = "Resolved path to the dotfiles directory";
      readOnly = true;
    };

    userSymlinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Symlinks to create in daniel's home directory.
        Keys are relative to home (or absolute paths).
        Values are symlink targets (absolute paths).
      '';
    };

    userFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Files to write in daniel's home directory.
        Keys are relative to home (or absolute paths).
        Values are file contents (written to nix store, then installed).
      '';
    };

    dconfSettings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "dconf settings to apply. Keys are dconf paths, values are attrsets of key=value.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.editableConfigFiles -> cfg.flakePath != null;
        message = "lyte.editableConfigFiles requires lyte.flakePath to be set explicitly";
      }
    ];

    # Run as daniel during system activation
    system.userActivationScripts.lyteUserEnv = {
      text = ''
        if [ "$(id -un)" = "daniel" ]; then
          ${danielScript}
        fi
      '';
    };
  };
}
