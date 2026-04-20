# User environment management (shared between NixOS and nix-darwin)
#
# Provides declarative user home directory file/symlink management,
# and on Linux: dconf settings.
# Activation mechanism differs per platform:
#   NixOS:      system.userActivationScripts (runs as user)
#   nix-darwin: system.activationScripts.postActivation (runs as root, sudo -u)
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  cfg = config.lyte;
  # Detect darwin by checking for a darwin-only option (avoids config recursion)
  isDarwin = !(options ? services && options.services ? fwupd);
  userHome = cfg.userHome;

  lnFlags = "-sf";

  # Generate dconf load commands from settings attrset (Linux only)
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
      manifestDir = "${home}/.local/state/lyte-user-env";
      manifestFile = "${manifestDir}/managed-symlinks";

      managedTargets = lib.mapAttrsToList (
        target: _source: if lib.hasPrefix "/" target then target else "${home}/${target}"
      ) symlinkEntries;

      currentManifest = pkgs.writeText "lyte-managed-symlinks" (
        lib.concatStringsSep "\n" (lib.sort builtins.lessThan managedTargets) + "\n"
      );

      cleanupCmd = ''
        # Stale symlink cleanup
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
              ln ${lnFlags} "${source}" "${fullTarget}" || echo "warning: failed to symlink ${fullTarget}" >&2
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
        echo "lyte-user-env: setting up user environment for ${cfg.username}..."
      ''
      + (lib.optionalString (symlinkEntries != { }) ("\n# Clean up stale symlinks\n" + cleanupCmd))
      + (lib.optionalString (symlinkEntries != { }) ("\n# Symlinks\n" + symlinkCmds))
      + (lib.optionalString (fileEntries != { }) ("\n# Written files\n" + fileCmds))
      + (lib.optionalString (!isDarwin && dconfEntries != { }) (
        "\n# dconf settings\n" + mkDconfScript dconfEntries
      ))
    );

  resolvedUserFiles = lib.mapAttrs (
    name: content: pkgs.writeText (builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name) content
  ) cfg.userFiles;

  activationScript = mkUserActivation userHome cfg.userSymlinks resolvedUserFiles (
    if !isDarwin then cfg.dconfSettings else { }
  );
in
{
  options.lyte = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "daniel";
      description = "Primary user account name for user-env management";
    };

    userHome = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.username}";
      description = ''
        Home directory of the primary user. Shared between NixOS and
        nix-darwin modules so references don't have to go through
        `config.users.users.<name>.home` (which doesn't exist on darwin).
      '';
    };

    userSshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        SSH public keys authorized for the primary user. Also written to
        `/etc/ssh/authorized_keys.d/<username>` as a break-glass path
        independent of the user's home-dir state.
      '';
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
        Symlinks to create in the user's home directory.
        Keys are relative to home (or absolute paths).
        Values are symlink targets (absolute paths).
      '';
    };

    userFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Files to write in the user's home directory.
        Keys are relative to home (or absolute paths).
        Values are file contents (written to nix store, then installed).
      '';
    };

    dconfSettings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "dconf settings to apply (Linux only). Keys are dconf paths, values are attrsets of key=value.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.editableConfigFiles -> cfg.flakePath != null;
        message = "lyte.editableConfigFiles requires lyte.flakePath to be set explicitly";
      }
    ];

    # Platform-specific activation mechanism
    system =
      if !isDarwin then
        {
          # NixOS: runs as user during activation
          userActivationScripts.lyteUserEnv = {
            text = ''
              if [ "$(id -un)" = "${cfg.username}" ]; then
                ${activationScript}
              fi
            '';
          };
        }
      else
        {
          # nix-darwin: runs as root, sudo to target user
          activationScripts.postActivation.text = ''
            sudo -u ${cfg.username} ${activationScript}
          '';
        };
  };
}
