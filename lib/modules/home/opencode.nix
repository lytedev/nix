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

    # Notification plugin (reuses claude-notify for desktop notifications and sound effects)
    home.file."${config.xdg.configHome}/opencode/plugins/notify.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/opencode/plugins/notify.ts";
  };
}
