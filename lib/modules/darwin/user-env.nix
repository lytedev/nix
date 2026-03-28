# User environment management for nix-darwin
#
# Provides declarative user home directory symlink management
# using nix-darwin's system.activationScripts.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lyte;
  userHome = config.users.users.${cfg.username}.home;

  # Build the user activation script
  mkUserActivation =
    home: symlinkEntries: fileEntries:
    let
      manifestDir = "${home}/.local/state/lyte-user-env";
      manifestFile = "${manifestDir}/managed-symlinks";

      managedTargets = lib.mapAttrsToList (
        target: _source: if lib.hasPrefix "/" target then target else "${home}/${target}"
      ) symlinkEntries;

      currentManifest = pkgs.writeText "lyte-managed-symlinks" (
        lib.concatStringsSep "\n" (lib.sort builtins.lessThan managedTargets) + "\n"
      );

      cleanupCmd = ''
        mkdir -p "${manifestDir}"
        if [ -f "${manifestFile}" ]; then
          while IFS= read -r old_target; do
            [ -z "$old_target" ] && continue
            if ! grep -qxF "$old_target" "${currentManifest}"; then
              if [ -L "$old_target" ]; then
                echo "lyte-user-env: removing stale symlink: $old_target" >&2
                rm -f "$old_target"
              fi
            fi
          done < "${manifestFile}"
        fi
        install -m 644 "${currentManifest}" "${manifestFile}"
      '';

      symlinkCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          target: source:
          let
            fullTarget = if lib.hasPrefix "/" target then target else "${home}/${target}";
          in
          ''
            mkdir -p "$(dirname "${fullTarget}")" || { echo "warning: failed to create parent dir for ${fullTarget}" >&2; }
            if [ "$(readlink -f "${fullTarget}")" != "$(readlink -f "${source}")" ]; then
              ln -sfh "${source}" "${fullTarget}" || echo "warning: failed to symlink ${fullTarget}" >&2
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
    ''
      echo "lyte-user-env: setting up user environment for ${cfg.username}..."
      ${lib.optionalString (symlinkEntries != { }) cleanupCmd}
      ${lib.optionalString (symlinkEntries != { }) symlinkCmds}
      ${lib.optionalString (fileEntries != { }) fileCmds}
    '';

  resolvedUserFiles = lib.mapAttrs (
    name: content: pkgs.writeText (builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name) content
  ) cfg.userFiles;
in
{
  options.lyte = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "daniel";
      description = "Primary user account name for user-env management";
    };

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
  };

  config = {
    assertions = [
      {
        assertion = cfg.editableConfigFiles -> cfg.flakePath != null;
        message = "lyte.editableConfigFiles requires lyte.flakePath to be set explicitly";
      }
    ];

    # nix-darwin uses system.activationScripts (run as root)
    # sudo -u daniel to run as the target user
    system.activationScripts.postActivation.text = ''
      sudo -u ${cfg.username} bash -c '${mkUserActivation userHome cfg.userSymlinks resolvedUserFiles}'
    '';
  };
}
