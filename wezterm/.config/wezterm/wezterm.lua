local wezterm = require 'wezterm'
local themegen = require 'themegen'

return {
	keys = {
		{ key = "f", mods = "CMD|CTRL", action = "ToggleFullScreen" },
		{
			key = 'Space',
			mods = 'CTRL|CMD',
			action = wezterm.action.CharSelect {
				copy_on_select = true,
				copy_to = 'ClipboardAndPrimarySelection',
			},
		},
	},

	font_size = 13,

	font = wezterm.font_with_fallback {
		'Berkeley Mono',
		'Fira Code Retina',
		'Noto Sans Mono',
		'JetBrains Mono',
		'Victor Mono',
		'Input Mono Narrow',
		'IBM Plex Mono',

		'Symbols Nerd Font',
	},
	front_end = "WebGpu",

	window_padding = { left = 0, right = 0, top = 0, bottom = 0 },

	enable_tab_bar = false,
	audible_bell = "Disabled",
	adjust_window_size_when_changing_font_size = false,
	hide_tab_bar_if_only_one_tab = true,

	-- Opacity settings
	-- window_background_opacity = 0.85,
	-- macos_window_background_blur = 16,
	use_fancy_tab_bar = false,

	-- macOS specific settings
	-- config.macos_window_hide_titlebar_when_maximized = true
	window_decorations = "RESIZE",
	-- config.macos_alt_is_meta = true

	-- Cursor settings
	hide_mouse_cursor_when_typing = true,

	-- Disabling automatic updates
	check_for_updates = false,
	window_close_confirmation = 'NeverPrompt',

	max_fps = 120,

	colors = themegen.generate_wezterm_colors(),
}
