local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.adjust_window_size_when_changing_font_size = false

config.color_scheme = 'catppuccin-mocha-sapphire';
config.font_size = 12.0
config.font = wezterm.font_with_fallback {
  { family = "IosevkaLyteTerm",        weight = 'Medium',  italic = false },
  { family = 'Symbols Nerd Font Mono', weight = 'Regular', italic = false },
  'Noto Color Emoji',
}

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.notification_handling = "SuppressFromFocusedTab"

local a = wezterm.action
local s = { domain = 'CurrentPaneDomain' }
local st = { domain = 'CurrentPaneDomain', args={'top'} }
local sr = { domain = 'CurrentPaneDomain', args={'right'} }
config.keys = {
  { key = 'j', mods = 'CTRL|SHIFT', action = a.SplitVertical(s) },
  { key = 'k', mods = 'CTRL|SHIFT', action = a.SplitVertical(st) },
  { key = 'l', mods = 'CTRL|SHIFT', action = a.SplitHorizontal(s) },
  { key = 'h', mods = 'CTRL|SHIFT', action = a.SplitHorizontal(sr) },
  { key = 'j', mods = 'CTRL', action = a.ActivatePaneDirection'Down' },
  { key = 'k', mods = 'CTRL', action = a.ActivatePaneDirection'Up' },
  { key = 'l', mods = 'CTRL', action = a.ActivatePaneDirection'Right' },
  { key = 'h', mods = 'CTRL', action = a.ActivatePaneDirection'Left' },
  { key = 'w', mods = 'CTRL', action = a.CloseCurrentPane{confirm=true} },
}

return config

-- config.window_background_opacity = 1.0
-- config.enable_kitty_keyboard = true
-- config.show_new_tab_button_in_tab_bar = true
-- config.notification_handling = "SuppressFromFocusedTab"

-- config.front_end = "WebGpu"
-- config.webgpu_power_preference = 'HighPerformance'
-- config.enable_wayland = true
-- config.use_ime = true

-- local function tab_title(tab_info)
--   local title = tab_info.tab_title
--   if title and #title > 0 then
--     return title
--   end
--   return tab_info.active_pane.title
-- end

-- wezterm.on('format-tab-title', function (tab, tabs, panes, config, hover, max_width)
-- wezterm.on('format-tab-title', function(tab, _, _, _, _, max_width)
--   local title = tab_title(tab)
--   return ' ' .. string.sub(title, 0, max_width - 2) .. ' '
-- end)

-- see nix module which has home manager create this color scheme file

-- config.inactive_pane_hsb = {
--   saturation = 0.8,
--   brightness = 0.7,
-- }

-- config.keys = {
-- {
--   key = 'Insert',
--   mods = 'SHIFT',
--   action = wezterm.action.PasteFrom 'Clipboard'
-- },
-- {
--   key = 'v',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.PasteFrom 'PrimarySelection'
-- },
-- {
--   key = 't',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.SpawnTab 'CurrentPaneDomain'
-- },
-- {
--   key = 'h',
--   mods = 'CTRL',
--   action = wezterm.action.ActivatePaneDirection 'Left'
-- },
-- {
--   key = 'l',
--   mods = 'CTRL',
--   action = wezterm.action.ActivatePaneDirection 'Right'
-- },
-- {
--   key = 'k',
--   mods = 'CTRL',
--   action = wezterm.action.ActivatePaneDirection 'Up'
-- },
-- {
--   key = 'j',
--   mods = 'CTRL',
--   action = wezterm.action.ActivatePaneDirection 'Down'
-- },
-- {
--   key = 'j',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
-- },
-- {
--   key = 'l',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
-- },
-- {
--   key = 'k',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.SplitVertical { args = { 'top' }, domain = 'CurrentPaneDomain' }
-- },
-- {
--   key = 'h',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.SplitHorizontal { args = { 'right' }, domain = 'CurrentPaneDomain' }
-- },
-- {
--   key = 'p',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.ActivateCommandPalette
-- },
-- {
--   key = 'w',
--   mods = 'CTRL|SHIFT',
--   action = wezterm.action.CloseCurrentPane { confirm = true },
-- },
-- {
--   key = 'w',
--   mods = 'CTRL|ALT|SHIFT',
--   action = wezterm.action.CloseCurrentTab { confirm = true },
-- },
-- {
--   key = 'l',
--   mods = 'CTRL|SHIFT|ALT',
--   action = wezterm.action.ShowDebugOverlay
-- },
-- {
--   key = 'r',
--   mods = 'CTRL|SHIFT|ALT',
--   action = wezterm.action.RotatePanes 'Clockwise'
-- },
-- }

-- config.unix_domains = {
--   {
--     name = 'unix',
--     local_echo_threshold_ms = 10,
--   },
-- }

-- config.default_gui_startup_args = { 'connect', 'unix' }
-- config.default_domain = 'unix'

-- config.window_padding = {
--   top = '0.5cell',
--   bottom = '0.5cell',
--   left = '1cell',
--   right = '1cell',
-- }
