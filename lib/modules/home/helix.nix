{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.programs.helix.enable {
    home.file."${config.xdg.configHome}/helix".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix"
    );

    home.file."${config.xdg.configHome}/lldb_vscode_rustc_primer.py".source =
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/helix/lldb_vscode_rustc_primer.py";
  };
}
