{
  pkgs,
  # font,
  colors,
  ...
}: {
  # docs: https://wezfurlong.org/wezterm/config/appearance.html#defining-your-own-colors
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

        selection_fg = bg;
        selection_bg = yellow;

        scrollbar_thumb = bg2;

        split = bg5;

        # indexed = { [136] = '#af8700' },
        tab_bar = {
          background = bg3;

          active_tab = {
            bg_color = primary;
            fg_color = bg;
            italic = false;
          };
          inactive_tab = {
            bg_color = bg2;
            fg_color = fgdim;
            italic = false;
          };
          inactive_tab_hover = {
            bg_color = bg3;
            fg_color = primary;
            italic = false;
          };
          new_tab = {
            bg_color = bg2;
            fg_color = fgdim;
            italic = false;
          };
          new_tab_hover = {
            bg_color = bg3;
            fg_color = primary;
            italic = false;
          };
        };

        compose_cursor = orange;

        # copy_mode_active_highlight_bg = { Color = '#000000' },
        # copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
        # copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
        # copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

        # quick_select_label_bg = { Color = 'peru' },
        # quick_select_label_fg = { Color = '#ffffff' },
        # quick_select_match_bg = { AnsiColor = 'Navy' },
        # quick_select_match_fg = { Color = '#ffffff' },
      };
    };
  };
}
