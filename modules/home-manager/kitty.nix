{
  colors,
  font,
  ...
}: {
  programs.kitty = {
    enable = true;
    darwinLaunchOptions = ["--single-instance"];
    shellIntegration = {
      enableFishIntegration = true;
    };
    settings = with colors.withHashPrefix; {
      "font_family" = font.name;
      "bold_font" = "${font.name} Heavy";
      "italic_font" = "${font.name} Italic";
      "bold_italic_font" = "${font.name} Heavy Italic";
      "font_size" = toString font.size;
      "inactive_text_alpha" = "0.5";
      "copy_on_select" = true;

      "scrollback_lines" = 500000;

      "symbol_map" = "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 Symbols Nerd Font Mono";

      # use `kitty + list-fonts --psnames` to get the font's PostScript name

      "allow_remote_control" = true;
      "listen_on" = "unix:/tmp/kitty";
      "repaint_delay" = 3;
      "input_delay" = 3;
      "sync_to_monitor" = true;

      "adjust_line_height" = 0;
      "window_padding_width" = "10.0";
      "window_margin_width" = "0.0";

      "confirm_os_window_close" = 0;

      "enabled_layouts" = "splits:split_axis=vertical,stack";

      "shell_integration" = "disabled";

      "enable_audio_bell" = true;
      "visual_bell_duration" = "0.25";
      "visual_bell_color" = bg3;

      "url_style" = "single";

      "strip_trailing_spaces" = "smart";

      # open_url_modifiers ctrl

      "tab_bar_align" = "left";
      "tab_bar_style" = "separator";
      "tab_separator" = ''""'';
      "tab_bar_edge" = "top";
      "tab_title_template" = ''"{fmt.fg.tab}{fmt.bg.tab} {activity_symbol}{title} "'';
      "active_tab_font_style" = "normal";

      ## name: Catppuccin Kitty Mocha
      ## author: Catppuccin Org
      ## license: MIT
      ## upstream: https://github.com/catppuccin/kitty/blob/main/mocha.conf
      ## blurb: Soothing pastel theme for the high-spirited!

      # The basic colors
      "foreground" = text;
      "background" = bg;
      "selection_foreground" = bg;
      "selection_background" = text;

      # Cursor colors
      "cursor" = text;
      "cursor_text_color" = bg;

      # URL underline color when hovering with mouse
      "url_color" = primary;

      # Kitty window border colors
      "active_border_color" = primary;
      "inactive_border_color" = bg3;
      "bell_border_color" = urgent;

      # OS Window titlebar colors
      "wayland_titlebar_color" = "system";
      "macos_titlebar_color" = "system";

      # Tab bar colors
      "active_tab_foreground" = bg;
      "active_tab_background" = primary;
      "inactive_tab_foreground" = fgdim;
      "inactive_tab_background" = bg2;
      "tab_bar_background" = bg;

      # Colors for marks (marked text in the terminal)
      "mark1_foreground" = bg;
      "mark1_background" = blue;
      "mark2_foreground" = bg;
      "mark2_background" = purple;
      "mark3_foreground" = bg;
      "mark3_background" = blue;

      # The 16 terminal colors

      # black
      "color0" = colors.withHashPrefix."0";
      "color8" = colors.withHashPrefix."8";

      # red
      "color1" = colors.withHashPrefix."1";
      "color9" = colors.withHashPrefix."9";

      # green
      "color2" = colors.withHashPrefix."2";
      "color10" = colors.withHashPrefix."10";

      # yellow
      "color3" = colors.withHashPrefix."3";
      "color11" = colors.withHashPrefix."11";

      # blue
      "color4" = colors.withHashPrefix."4";
      "color12" = colors.withHashPrefix."12";

      # magenta
      "color5" = colors.withHashPrefix."5";
      "color13" = colors.withHashPrefix."13";

      # cyan
      "color6" = colors.withHashPrefix."6";
      "color14" = colors.withHashPrefix."14";

      # white
      "color7" = colors.withHashPrefix."7";
      "color15" = colors.withHashPrefix."15";
    };
    keybindings = {
      "ctrl+shift+1" = "change_font_size all 12.5";
      "ctrl+shift+2" = "change_font_size all 18.5";
      "ctrl+shift+3" = "change_font_size all 26";
      "ctrl+shift+4" = "change_font_size all 32";
      "ctrl+shift+5" = "change_font_size all 48";
      "ctrl+shift+o" = "launch --type=tab --stdin-source=@screen_scrollback $EDITOR";

      "ctrl+shift+equal" = "change_font_size all +0.5";
      "ctrl+shift+minus" = "change_font_size all -0.5";

      "shift+insert" = "paste_from_clipboard";
      "ctrl+shift+v" = "paste_from_selection";
      "ctrl+shift+c" = "copy_to_clipboard";

      # kill pane
      "ctrl+shift+q" = "close_window";

      # kill tab
      "ctrl+alt+shift+q" = "close_tab";

      "ctrl+shift+j" = "launch --location=hsplit --cwd=current";
      "ctrl+shift+l" = "launch --location=vsplit --cwd=current";

      "ctrl+alt+shift+k" = "move_window up";
      "ctrl+alt+shift+h" = "move_window left";
      "ctrl+alt+shift+l" = "move_window right";
      "ctrl+alt+shift+j" = "move_window down";

      "ctrl+h" = "neighboring_window left";
      "ctrl+l" = "neighboring_window right";
      "ctrl+k" = "neighboring_window up";
      "ctrl+j" = "neighboring_window down";
      "ctrl+shift+n" = "nth_window -1";
      "ctrl+shift+space>u" = "kitten hints --type=url --program @";

      "ctrl+shift+z" = "toggle_layout stack";
    };
  };
}
