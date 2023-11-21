{colors, ...}: {
  programs.broot = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      modal = false; # vim mode?

      verbs = [
        {
          invocation = "edit";
          shortcut = "e";
          execution = "$EDITOR {file}";
        }
      ];

      skin = with colors.withHashPrefix; {
        status_normal_fg = fg;
        status_normal_bg = bg;
        status_error_fg = red;
        status_error_bg = yellow;
        tree_fg = red;
        selected_line_bg = bg2;
        permissions_fg = purple;
        size_bar_full_bg = red;
        size_bar_void_bg = bg;
        directory_fg = yellow;
        input_fg = blue;
        flag_value_fg = yellow;
        table_border_fg = red;
        code_fg = yellow;
      };
    };
  };
}
