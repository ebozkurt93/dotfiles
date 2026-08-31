local M = {}

-- Non-text contrast minimum (WCAG 2.1 SC 1.4.11) for mako/Quickshell fills reusing extracted colors as fills, not text.
local MIN_UI_CONTRAST = 3.0

local function hex_to_rgb(hex)
	hex = hex:gsub('#', '')
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function srgb_channel(c)
	c = c / 255
	if c <= 0.03928 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function relative_luminance(hex)
	local r, g, b = hex_to_rgb(hex)
	return 0.2126 * srgb_channel(r) + 0.7152 * srgb_channel(g) + 0.0722 * srgb_channel(b)
end

local function contrast_ratio(hex1, hex2)
	local l1, l2 = relative_luminance(hex1), relative_luminance(hex2)
	local lighter, darker = math.max(l1, l2), math.min(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)
end

local function mix_hex(hex1, hex2, t)
	local r1, g1, b1 = hex_to_rgb(hex1)
	local r2, g2, b2 = hex_to_rgb(hex2)
	return ("#%02x%02x%02x"):format(
		math.floor(r1 + (r2 - r1) * t + 0.5),
		math.floor(g1 + (g2 - g1) * t + 0.5),
		math.floor(b1 + (b2 - b1) * t + 0.5)
	)
end

local function ensure_ui_contrast(color, bg, fg)
	if contrast_ratio(color, bg) >= MIN_UI_CONTRAST then
		return color
	end
	local fallback = mix_hex(bg, fg, 0.35)
	if contrast_ratio(fallback, bg) >= MIN_UI_CONTRAST then
		return fallback
	end
	return fg
end

-- Text contrast minimum (WCAG 2.1 SC 1.4.3) for text drawn on top of a fill, e.g. the workspace pill's number.
local MIN_TEXT_CONTRAST = 4.5
local function best_readable_text(fill, candidates)
	for _, c in ipairs(candidates) do
		if contrast_ratio(c, fill) >= MIN_TEXT_CONTRAST then
			return c
		end
	end
	if contrast_ratio("#000000", fill) >= contrast_ratio("#ffffff", fill) then
		return "#000000"
	end
	return "#ffffff"
end

function M.find_colors()
	local normal = vim.api.nvim_get_hl_by_name("Normal", true)
	if normal == nil or normal.background == nil or normal.foreground == nil then
		-- this at least happens if the transparency in neovim is enabled
		-- instead of throwing an error, lets try to temporarily toggle transparency handle this by ourselves
		vim.cmd [[ TransparentToggle ]]
		normal = vim.api.nvim_get_hl_by_name("Normal", true)
		vim.cmd [[ TransparentToggle ]]
	end
	local normal_bg = ("#%06x"):format(normal.background)
	local normal_fg = ("#%06x"):format(normal.foreground)
	local cursor = vim.api.nvim_get_hl_by_name("Cursor", true)
	local cursor_bg = ("#%06x"):format(cursor.background or normal.background)
	local cursor_fg = ("#%06x"):format(cursor.foreground or normal.background)
	local visual = vim.api.nvim_get_hl_by_name("Visual", true)
	local visual_bg = ("#%06x"):format(visual.background or normal.background)
	local visual_fg = ("#%06x"):format(visual.foreground or normal.foreground)

	-- Most-used color across a role's highlight groups; ties broken by groups' list order, not table iteration order.
	local function role_color(groups, fallback)
		local counts = {}
		local resolved = {}
		for _, group in ipairs(groups) do
			local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group, true)
			if ok and hl and hl.foreground then
				local color = ("#%06x"):format(hl.foreground)
				counts[color] = (counts[color] or 0) + 1
				resolved[#resolved + 1] = color
			end
		end

		local best_count = 0
		for _, count in pairs(counts) do
			if count > best_count then
				best_count = count
			end
		end
		if best_count == 0 then
			return fallback
		end
		for _, color in ipairs(resolved) do
			if counts[color] == best_count then
				return color
			end
		end
		return fallback
	end

	local error = role_color({ "DiagnosticError", "Error", "ErrorMsg", "@comment.error" }, normal_fg)
	local string = role_color({
		"String", "@string", "@string.documentation", "@string.regexp", "@string.special", "Character", "@character",
	}, normal_fg)
	local accent = role_color({
		"Function", "@function", "@function.call", "@function.method", "@function.method.call", "@function.builtin",
		"@function.macro", "@attribute", "@tag", "Title", "FloatTitle", "PmenuMatch",
	}, normal_fg)
	local type = role_color({ "Type", "@type", "@type.definition", "DiagnosticInfo", "Question", "Directory" }, normal_fg)
	local special = role_color({
		"Constant", "@constant", "@constant.builtin", "@constant.macro", "Special", "Debug", "@markup.link.label",
	}, accent)
	local keyword = role_color({
		"Keyword", "@keyword", "@keyword.function", "@keyword.return", "@keyword.conditional", "@keyword.repeat",
		"Statement", "PreProc", "Operator", "@operator", "@keyword.operator",
	}, normal_fg)
	local comment = role_color({ "Comment", "@comment", "LineNr", "NonText", "Whitespace" }, normal_bg)

	-- Contrast-checked for mako/Quickshell fills; color0-15 below (kitty/ghostty/wezterm text) stay untouched.
	local ui_accent = ensure_ui_contrast(accent, normal_bg, normal_fg)
	local ui_danger = ensure_ui_contrast(error, normal_bg, normal_fg)
	local ui_muted = ensure_ui_contrast(comment, normal_bg, normal_fg)

	local my_colors = {
		bg = normal_bg,
		fg = normal_fg,
		mode = vim.o.background,
		accent = ui_accent,
		danger = ui_danger,
		muted = ui_muted,
		-- Text drawn on top of the accent/muted fills, e.g. the workspace pill's number.
		text_on_accent = best_readable_text(ui_accent, { normal_fg, normal_bg }),
		text_on_muted = best_readable_text(ui_muted, { normal_fg, normal_bg }),

		selection_background = visual_bg,
		selection_foreground = visual_fg,

		cursor_background = cursor_bg,
		cursor_foreground = cursor_fg,

		color0  = vim.g.terminal_color_0  or normal_bg,
		color1  = vim.g.terminal_color_1  or error,
		color2  = vim.g.terminal_color_2  or string,
		color3  = vim.g.terminal_color_3  or accent,
		color4  = vim.g.terminal_color_4  or type,
		color5  = vim.g.terminal_color_5  or special,
		color6  = vim.g.terminal_color_6  or keyword,
		color7  = vim.g.terminal_color_7  or normal_fg,
		color8  = vim.g.terminal_color_8  or comment,
		color9  = vim.g.terminal_color_9  or error,
		color10 = vim.g.terminal_color_10 or string,
		color11 = vim.g.terminal_color_11 or accent,
		color12 = vim.g.terminal_color_12 or type,
		color13 = vim.g.terminal_color_13 or special,
		color14 = vim.g.terminal_color_14 or keyword,
		color15 = vim.g.terminal_color_15 or normal_fg,
	}
	return my_colors
end

-- Simple string interpolation.
--
-- Example template: "${name} is ${value}"
--
---@param str string template string
---@param table table key value pairs to replace in the string
function M.template(str, table)
	return (
		str:gsub("($%b{})", function(w)
			return vim.tbl_get(table, unpack(vim.split(w:sub(3, -2), ".", { plain = true }))) or w
		end)
		)
end

function M.generate(name)
	M.generate_for_kitty(name)
	M.generate_extras(name)
end

-- The non-kitty consumers, split out so the pre-shipped-kitty-theme fast path can still keep them in sync.
function M.generate_extras(name)
	M.generate_for_mako(name)
	M.generate_for_quickshell(name)
	M.write_mode()
end

-- Drops the current dark/light mode where non-nvim tooling (e.g. the zsh dconf sync) can read it.
function M.write_mode()
	vim.fn.system("echo -n '" .. vim.o.background .. "' > ~/.cache/dotfiles-theme-mode")
end

function M.generate_for_kitty(name)
	local blank_name = name == nil or name == ''
	local kitty = M.template(
		[[
# vim:ft=kitty
## name: ${_style_name}
## nvim_auto_generated: true

background ${bg}
foreground ${fg}
selection_background ${selection_background}
selection_foreground ${selection_foreground}
cursor ${fg}
cursor_text_color ${bg}

# Tabs
active_tab_background ${bg}
active_tab_foreground ${fg}
inactive_tab_background ${bg}
inactive_tab_foreground ${fg}
tab_bar_background ${bg}

# normal
color0 ${color0}
color1 ${color1}
color2 ${color2}
color3 ${color3}
color4 ${color4}
color5 ${color5}
color6 ${color6}
color7 ${color7}

# bright
color8 ${color8}
color9 ${color9}
color10 ${color10}
color11 ${color11}
color12 ${color12}
color13 ${color13}
color14 ${color14}
color15 ${color15}
]],
		vim.tbl_extend("force", M.find_colors(), { _style_name = name or 'Current theme' })
	)
	vim.fn.system("echo '" .. kitty .. "' > ~/dotfiles/kitty/.config/kitty/current-theme.conf")
	if not blank_name then
		vim.fn.system("echo '" .. kitty .. "' > ~/dotfiles/kitty/.config/kitty/themes/" .. name .. ".conf")
		vim.notify('Generated and stored theme ' .. name)
	else
		vim.notify('Generated theme')
	end
	return kitty
end

function M.generate_for_ghostty(name)
	local blank_name = name == nil or name == ''
	local ghostty_template = M.template(
		[[
# Auto-generated theme file

palette = 0=${color0}
palette = 1=${color1}
palette = 2=${color2}
palette = 3=${color3}
palette = 4=${color4}
palette = 5=${color5}
palette = 6=${color6}
palette = 7=${color7}
palette = 8=${color8}
palette = 9=${color9}
palette = 10=${color10}
palette = 11=${color11}
palette = 12=${color12}
palette = 13=${color13}
palette = 14=${color14}
palette = 15=${color15}

background = ${bg}
foreground = ${fg}
cursor-color = ${fg}
selection-background = ${selection_background}
selection-foreground = ${selection_foreground}
]],
		vim.tbl_extend("force", M.find_colors(), { _style_name = name or 'Current theme' })
	)
	vim.fn.system("echo '" .. ghostty_template .. "' > ~/dotfiles/ghostty/.config/ghostty/theme")
	if not blank_name then
		vim.fn.system("echo '" .. ghostty_template .. "' > ~/dotfiles/ghostty/.config/ghostty/themes/" .. name .. "")
		print('Generated and stored ghostty theme ' .. name)
	else
		print('Generated ghostty theme')
	end
	return ghostty_template
end

function M.generate_for_mako(name)
	local mako = M.template(
		[[
# Auto-generated theme file
## nvim_auto_generated: true

background-color=${bg}
text-color=${fg}
border-color=${accent}
]],
		vim.tbl_extend("force", M.find_colors(), { _style_name = name or 'Current theme' })
	)
	vim.fn.system("echo '" .. mako .. "' > ~/dotfiles/mako/.config/mako/colors.conf")
	return mako
end

function M.generate_for_quickshell(name)
	local color_qml = M.template(
		[[
pragma Singleton
import QtQuick
import Quickshell

// Auto-generated theme file
// nvim_auto_generated: true
Singleton {
    id: root

    // Base palette, generated from the active nvim colorscheme (${_style_name}).
    readonly property color background: "${bg}"
    readonly property color foreground: "${fg}"
    readonly property color muted: "${muted}"
    readonly property color accent: "${accent}"
    readonly property color danger: "${danger}"
    readonly property color dangerText: "${fg}"
    // Readable text for content drawn on top of the accent/muted fills.
    readonly property color textOnAccent: "${text_on_accent}"
    readonly property color textOnMuted: "${text_on_muted}"

    readonly property color transparent: "transparent"

    readonly property QtObject bar: QtObject {
        property color background: root.background
        property color text: root.foreground
        property color workspaceActive: root.accent
        property color workspaceInactive: root.muted
        property color textOnWorkspaceActive: root.textOnAccent
        property color textOnWorkspaceInactive: root.textOnMuted
    }

    readonly property QtObject lock: QtObject {
        property color background: root.background
        property color text: root.foreground
        property color textError: root.danger
        property color placeholder: root.muted
        property color border: root.muted
        property color borderError: root.danger
        property color passwordBoxBackground: root.background
        property color selection: root.accent
        property color textOnAccent: root.textOnAccent
        property color textOnMuted: root.textOnMuted
        property color powerButtonBackground: root.muted
        property color powerButtonBorder: root.muted
        property color powerButtonHover: root.muted
        property color dangerButtonBackground: root.background
        property color dangerButtonBorder: root.danger
        property color dangerButtonText: root.danger
    }

    readonly property QtObject launcher: QtObject {
        property color scrim: "#000000"
        property color cardBackground: root.background
        property color cardBorder: root.muted
        property color inputBackground: root.background
        property color inputBorder: root.muted
        property color text: root.foreground
        property color textMuted: root.muted
        property color textOnMuted: root.textOnMuted
        property color selection: root.accent
        property color selectionBackground: root.muted
        property color selectionBorder: root.accent
        property color textOnAccent: root.textOnAccent
    }
}
]],
		vim.tbl_extend("force", M.find_colors(), { _style_name = name or 'Current theme' })
	)
	vim.fn.system("echo '" .. color_qml .. "' > ~/dotfiles/quickshell/.config/quickshell/Commons/Color.qml")
	return color_qml
end

return M
