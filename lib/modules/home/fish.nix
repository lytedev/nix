{
  lib,
  config,
  pkgs,
  ...
}:
let
  symlink =
    path: config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/fish/${path}";
in
{
  config = lib.mkIf config.programs.fish.enable {
    home = {
      packages = [
        pkgs.gawk # used in prompt
      ];
    };

    programs.fish = {
      # Source live from dotfiles so edits take effect without rebuilding
      shellInit = "source ${config.lyte.flakePath}/dotfiles/fish/shellInit.fish";
      interactiveShellInit = "source ${config.lyte.flakePath}/dotfiles/fish/interactiveShellInit.fish";
      loginShellInit = "";
      shellAbbrs = { };
    };

    # Fish functions as individual native files (autoloaded from ~/.config/fish/functions/)
    home.file."${config.xdg.configHome}/fish/functions/d.fish".source = symlink "functions/d.fish";
    home.file."${config.xdg.configHome}/fish/functions/c.fish".source = symlink "functions/c.fish";
    home.file."${config.xdg.configHome}/fish/functions/ltl.fish".source = symlink "functions/ltl.fish";
    home.file."${config.xdg.configHome}/fish/functions/g.fish".source = symlink "functions/g.fish";
    home.file."${config.xdg.configHome}/fish/functions/lag.fish".source = symlink "functions/lag.fish";
    home.file."${config.xdg.configHome}/fish/functions/jujutsu-git-colocate.fish".source =
      symlink "functions/jujutsu-git-colocate.fish";

    # Aliases loaded via conf.d
    home.file."${config.xdg.configHome}/fish/conf.d/aliases.fish".source =
      symlink "conf.d/aliases.fish";
  };
}
