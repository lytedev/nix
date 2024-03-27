local wezterm = require'wezterm'
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.font = wezterm.font_with_fallback{
  { family = "IosevkaLyteTerm", weight = 'Medium', italic = false },
  { family = 'Symbols Nerd Font Mono', weight = 'Regular', italic = false },
  'Noto Color Emoji',
}
config.font_size = 12.0
-- config.window_frame.font = config.font
-- config.window_frame.font_size = font_size

config.default_cursor_style = 'BlinkingBar'
-- config.disable_default_key_bindings = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.window_background_opacity = 1.0
config.enable_kitty_keyboard = true
config.show_new_tab_button_in_tab_bar = true

local function tab_title(tab_info)
  local title = tab_info.tab_title
  if title and #title > 0 then
    return title
  end
  return tab_info.active_pane.title
end

-- wezterm.on('format-tab-title', function (tab, tabs, panes, config, hover, max_width)
wezterm.on('format-tab-title', function (tab, _, _, _, _, max_width)
  local title = tab_title(tab)
  return ' ' .. string.sub(title, 0, max_width - 2) .. ' '
end)

-- see nix module which has home manager create this color scheme file
config.color_scheme = 'catppuccin-mocha-sapphire';

config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.7,
}

config.keys = {
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
    key = 't',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab'CurrentPaneDomain'
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
    mods = 'CTRL',
    action = wezterm.action.ActivatePaneDirection'Down'
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
    key = 'k',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitVertical{args={'top'},domain='CurrentPaneDomain'}
  },
  {
    key = 'h',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitHorizontal{args={'right'},domain='CurrentPaneDomain'}
  },
  {
    key = 'p',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateCommandPalette
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
