local wezterm = require 'wezterm'
local themegen = require 'themegen'
local overrides = require 'overrides'

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

	font_size = overrides.font_size or 13,

	font = wezterm.font_with_fallback {
		{ family = overrides.font, weight = 'DemiBold' },
		overrides.font,
		'Fira Code Retina',
		'Victor Mono',
		'JetBrains Mono',
		'IBM Plex Mono',
		'Input Mono Narrow',
		'Noto Sans Mono',
		'Iosevka',
		'Berkeley Mono',

		'Apple Color Emoji',
		'Symbols Nerd Font',
	},

	colors = themegen.generate_wezterm_colors(),
	window_padding = overrides.window_padding or { left = 0, right = 0, top = 0, bottom = 0 },

	enable_tab_bar = false,
	audible_bell = "Disabled",
	adjust_window_size_when_changing_font_size = false,
	hide_tab_bar_if_only_one_tab = true,

	window_background_opacity = overrides.window_background_opacity or 1,
	macos_window_background_blur = 16,
	use_fancy_tab_bar = false,
	window_decorations = "RESIZE",
	hide_mouse_cursor_when_typing = true,
	check_for_updates = false,
	window_close_confirmation = 'NeverPrompt',
	max_fps = 120,
	force_reverse_video_cursor = true
}
