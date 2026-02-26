{
  config,
  ...
}:
{
  config = {
    home.file."${config.xdg.configHome}/opencode/opencode.jsonc".source =
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/opencode/opencode.jsonc";

    # Reuse the shared Claude/agent instructions
    home.file."${config.xdg.configHome}/opencode/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/lib/modules/home/claude/CLAUDE.md";
  };
}
