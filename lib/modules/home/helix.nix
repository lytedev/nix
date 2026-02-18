{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.programs.helix.enable {
    home.file."${config.xdg.configHome}/helix/config.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix/config.toml"
    );
    home.file."${config.xdg.configHome}/helix/languages.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix/languages.toml"
    );
    home.file."${config.xdg.configHome}/helix/themes/custom.toml".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix/themes/custom.toml"
    );

    home.file."${config.xdg.configHome}/lldb_vscode_rustc_primer.py".source =
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix/lldb_vscode_rustc_primer.py";
  };
}
