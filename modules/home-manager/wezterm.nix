{
  pkgs,
  # font,
  colors,
  ...
}: {
  programs.wezterm = with colors.withHashPrefix; {
    enable = true;
    extraConfig = builtins.readFile ./wezterm/config.lua;
    colorSchemes = {
      catppuccin-mocha-sapphire = {
        ansi = map (x: colors.withHashPrefix.${toString x}) (pkgs.lib.lists.range 0 7);
        brights = map (x: colors.withHashPrefix.${toString (x + 8)}) (pkgs.lib.lists.range 0 7);

        foreground = fg;
        background = bg;

        cursor_fg = bg;
        cursor_bg = text;
        cursor_border = text;
      };
    };
  };
}
