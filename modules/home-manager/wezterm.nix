{
  font,
  colors,
  ...
}: {
  programs.wezterm = {
    enable = true;
    extraConfig = with colors.withHashPrefix; ''
      local wezterm = require'wezterm'

      local config = {}

      if wezterm.config_builder then
        config = wezterm.config_builder()
      end

      local font_spec = { family = '${font.name}', weight = 'Medium', italic = false }
      local font_size = ${toString font.size}.0

      local font = wezterm.font_with_fallback{
        font_spec,
        { family = 'Symbols Nerd Font Mono', weight = 'Regular', italic = false },
        'Noto Color Emoji',
      }

      config.default_cursor_style = 'BlinkingBar'

      config.font = font
      config.font_size = font_size

      config.hide_tab_bar_if_only_one_tab = true
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = false
      config.window_background_opacity = 1.0

      -- config.window_frame.font = config.font
      -- config.window_frame.font_size = font_size

      config.colors = {
        foreground = '${fg}',
        background = '${primary}',
        cursor_bg = '${text}',
        cursor_fg = '${bg}',
        -- Specifies the border color of the cursor when the cursor style is set to Block,
        -- or the color of the vertical or horizontal bar when the cursor style is set to
        -- Bar or Underline.
        cursor_border = '#52ad70',

        -- the foreground color of selected text
        selection_fg = 'black',
        -- the background color of selected text
        selection_bg = '#fffacd',

        -- The color of the scrollbar "thumb"; the portion that represents the current viewport
        scrollbar_thumb = '#222222',

        -- The color of the split lines between panes
        split = '#444444',

        ansi = {
          'black',
          'maroon',
          'green',
          'olive',
          'navy',
          'purple',
          'teal',
          'silver',
        },
        brights = {
          'grey',
          'red',
          'lime',
          'yellow',
          'blue',
          'fuchsia',
          'aqua',
          'white',
        },

        -- Arbitrary colors of the palette in the range from 16 to 255
        indexed = { [136] = '#af8700' },

        -- Since: 20220319-142410-0fcdea07
        -- When the IME, a dead key or a leader key are being processed and are effectively
        -- holding input pending the result of input composition, change the cursor
        -- to this color to give a visual cue about the compose state.
        compose_cursor = 'orange',

        -- Colors for copy_mode and quick_select
        -- available since: 20220807-113146-c2fee766
        -- In copy_mode, the color of the active text is:
        -- 1. copy_mode_active_highlight_* if additional text was selected using the mouse
        -- 2. selection_* otherwise
        copy_mode_active_highlight_bg = { Color = '#000000' },
        -- use `AnsiColor` to specify one of the ansi color palette values
        -- (index 0-15) using one of the names "Black", "Maroon", "Green",
        --  "Olive", "Navy", "Purple", "Teal", "Silver", "Grey", "Red", "Lime",
        -- "Yellow", "Blue", "Fuchsia", "Aqua" or "White".
        copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
        copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
        copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

        quick_select_label_bg = { Color = 'peru' },
        quick_select_label_fg = { Color = '#ffffff' },
        quick_select_match_bg = { AnsiColor = 'Navy' },
        quick_select_match_fg = { Color = '#ffffff' },
      }


      config.inactive_pane_hsb = {
        saturation = 0.8,
        brightness = 0.7,
      }

      config.keys = {
        {
          key = 'j',
          mods = 'CTRL',
          action = wezterm.action.ActivatePaneDirection'Down'
        },
        {
          key = 'Insert',
          mods = 'SHIFT',
          action = wezterm.action.PasteFrom'Clipboard'
        },
        {
          key = 'v',
          mods = 'CTRL|SHIFT',
          action = wezterm.action.PasteFrom'PrimarySelection'
        },
        {
          key = 'h',
          mods = 'CTRL',
          action = wezterm.action.ActivatePaneDirection'Left'
        },
        {
          key = 'l',
          mods = 'CTRL',
          action = wezterm.action.ActivatePaneDirection'Right'
        },
        {
          key = 'k',
          mods = 'CTRL',
          action = wezterm.action.ActivatePaneDirection'Up'
        },
        {
          key = 'j',
          mods = 'CTRL|SHIFT',
          action = wezterm.action.SplitVertical{domain='CurrentPaneDomain'}
        },
        {
          key = 'l',
          mods = 'CTRL|SHIFT',
          action = wezterm.action.SplitHorizontal{domain='CurrentPaneDomain'}
        },
        {
          key = 'l',
          mods = 'CTRL|SHIFT|ALT',
          action = wezterm.action.ShowDebugOverlay
        },
        {
          key = 'r',
          mods = 'CTRL|SHIFT|ALT',
          action = wezterm.action.RotatePanes'Clockwise'
        },
      }

      -- config.unix_domains = {
        -- {
          -- name = 'unix',
          -- local_echo_threshold_ms = 10,
        -- },
      -- }

      -- config.default_gui_startup_args = { 'connect', 'unix' }
      -- config.default_domain = 'unix'

      config.window_padding = {
        top = '0.5cell',
        bottom = '0.5cell',
        left = '1cell',
        right = '1cell',
      }

      return config
    '';
  };
}
