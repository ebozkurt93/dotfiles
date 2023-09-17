--local custom_gruvbox = require'lualine.themes.gruvbox'

-- Change the background of lualine_c section for normal mode
--custom_gruvbox.normal.c.bg = '#112233'

-- can be used for passing symbols in luasnip
-- local s = require('lspsaga.symbolwinbar').get_symbol_node

local function get_active_lsp_clients()
	local bf = vim.api.nvim_get_current_buf()
	local tbl = vim.tbl_map(function(t) return t.name end, vim.lsp.get_active_clients({bufnr = bf}))
	return vim.trim(table.concat(tbl, ', '))
end

local function window_nr()
	return vim.api.nvim_win_get_number(0)
end

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
		lualine_c = { get_active_lsp_clients },
		lualine_x = { { "require'nvim-possession'.status()" }, 'encoding', 'filetype', 'filesize' },
		lualine_y = { 'searchcount', 'progress' },
		lualine_z = { 'location' }
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { window_nr, 'filename', 'diff', 'diagnostics' },
		lualine_x = { 'searchcount', 'progress', 'location' },
		lualine_y = {},
		lualine_z = {}
	},
	tabline = {
		lualine_a = {
			{
				'tabs',
				max_length = vim.o.columns, -- Maximum width of tabs component.
				mode = 2, -- 0: Shows tab_nr - 1: Shows tab_name - 2: Shows tab_nr + tab_name
				tabs_color = {
					active = 'lualine_b_normal',
					inactive = 'lualine_c_normal',
				},
				-- fmt = function(s, c)
				-- 	return (c.tabnr ~= vim.fn.tabpagenr() and c.tabnr .. ' ' or '') .. s
				-- end
			},
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {},
		lualine_z = {}
	},
	winbar = {
		lualine_a = {},
		lualine_b = { { 'filename', path = 1 }, },
		lualine_c = {},
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
