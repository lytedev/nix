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

      function tab_title(tab_info)
        local title = tab_info.tab_title
        if title and #title > 0 then
          return title
        end
        return tab_info.active_pane.title
      end

      wezterm.on('format-tab-title', function (tab, tabs, panes, config, hover, max_width)
        local title = tab_title(tab)
        return ' ' .. string.sub(title, 0, max_width - 2) .. ' '
      end)

      config.colors = {
        foreground = '${fg}',
        background = '${bg}',
        cursor_bg = '${text}',
        cursor_fg = '${bg}',
        cursor_border = '${text}',

        selection_fg = '${bg}',
        selection_bg = '${yellow}',

        scrollbar_thumb = '${bg2}',

        split = '${bg5}',

        ansi = {
          '${colors.withHashPrefix."0"}',
          '${colors.withHashPrefix."1"}',
          '${colors.withHashPrefix."2"}',
          '${colors.withHashPrefix."3"}',
          '${colors.withHashPrefix."4"}',
          '${colors.withHashPrefix."5"}',
          '${colors.withHashPrefix."6"}',
          '${colors.withHashPrefix."7"}',
        },
        brights = {
          '${colors.withHashPrefix."8"}',
          '${colors.withHashPrefix."9"}',
          '${colors.withHashPrefix."10"}',
          '${colors.withHashPrefix."11"}',
          '${colors.withHashPrefix."12"}',
          '${colors.withHashPrefix."13"}',
          '${colors.withHashPrefix."14"}',
          '${colors.withHashPrefix."15"}',
        },

        tab_bar = {
          background = '${bg3}',

          active_tab = {
            bg_color = '${primary}',
            fg_color = '${bg}',
            italic = false,
          },
          inactive_tab = {
            bg_color = '${bg2}',
            fg_color = '${fgdim}',
            italic = false,
          },
          inactive_tab_hover = {
            bg_color = '${bg3}',
            fg_color = '${primary}',
            italic = false,
          },
          new_tab = {
            bg_color = '${bg2}',
            fg_color = '${fgdim}',
            italic = false,
          },
          new_tab_hover = {
            bg_color = '${bg3}',
            fg_color = '${primary}',
            italic = false,
          },
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
