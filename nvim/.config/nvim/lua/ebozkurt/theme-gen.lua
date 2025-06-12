local M = {}

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

	local my_colors = {
		bg = normal_bg,
		fg = normal_fg,

		selection_background = visual_bg,
		selection_foreground = visual_fg,

		cursor_background = cursor_bg,
		cursor_foreground = cursor_fg,
		-- bg_visual = bg,

		color0 = vim.g.terminal_color_0,
		color1 = vim.g.terminal_color_1,
		color2 = vim.g.terminal_color_2,
		color3 = vim.g.terminal_color_3,
		color4 = vim.g.terminal_color_4,
		color5 = vim.g.terminal_color_5,
		color6 = vim.g.terminal_color_6,
		color7 = vim.g.terminal_color_7,
		color8 = vim.g.terminal_color_8,
		color9 = vim.g.terminal_color_9,
		color10 = vim.g.terminal_color_10,
		color11 = vim.g.terminal_color_11,
		color12 = vim.g.terminal_color_12,
		color13 = vim.g.terminal_color_13,
		color14 = vim.g.terminal_color_14,
		color15 = vim.g.terminal_color_15,
		--
		-- active_tab_background = vim.g.active_tab_background,
		-- active_tab_foreground = vim.g.active_tab_foreground,
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
	vim.defer_fn(function()
		vim.notify("")
	end, 3000)
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

return M
