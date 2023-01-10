--local custom_gruvbox = require'lualine.themes.gruvbox'

-- Change the background of lualine_c section for normal mode
--custom_gruvbox.normal.c.bg = '#112233'

-- can be used for passing symbols in luasnip
-- local s = require('lspsaga.symbolwinbar').get_symbol_node

require('lualine').setup {
	options = {
		icons_enabled = true,
		theme = 'auto',
		-- component_separators = { left = '', right = '' },
		-- section_separators = { left = '', right = '' },
		-- rounded mode
		component_separators = { left = '', right = '' },
		section_separators = { left = '', right = '' },

		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = false,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
		}
	},
	sections = {
		lualine_a = { 'mode' },
		lualine_b = { 'branch', 'diff', 'diagnostics' },
		lualine_c = {},
		lualine_x = { 'encoding', 'filetype', 'filesize' },
		lualine_y = { 'progress', 'searchcount' },
		lualine_z = { 'location' }
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { 'filename', 'diff' },
		lualine_x = { 'location' },
		lualine_y = {},
		lualine_z = {}
	},
	tabline = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {
			{
				'tabs',
				max_length = vim.o.columns, -- Maximum width of tabs component.
				component_separators = { left = '' },
				mode = 1 -- 0: Shows tab_nr - 1: Shows tab_name - 2: Shows tab_nr + tab_name
			},
		},
		lualine_x = {},
		lualine_y = {},
		lualine_z = {}
	},
	winbar = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { { 'filename', path = 1 }, },
		lualine_x = {},
		lualine_y = {},
		lualine_z = {}
	},
	inactive_winbar = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { { 'filename', path = 1 }, },
		lualine_x = {},
		lualine_y = {},
		lualine_z = {}
	},
	extensions = {}
}

vim.api.nvim_exec_autocmds('User', { pattern = 'LuaLineInitialized' })
