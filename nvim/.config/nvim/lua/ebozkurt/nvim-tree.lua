-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local function my_on_attach(bufnr)
	local api = require('nvim-tree.api')

	local function opts(desc)
		return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
	end

	api.config.mappings.default_on_attach(bufnr)

	vim.keymap.set('n', '<C-u>', api.tree.change_root_to_parent, opts('Change root to parent'))
	vim.keymap.set('n', '<C-r>', api.tree.change_root_to_node, opts('Change root to note'))
end

require("nvim-tree").setup({
	sort_by = "case_sensitive",
	on_attach = my_on_attach,
	view = {
		adaptive_size = true,
		preserve_window_proportions = true,
		-- mappings = {
		-- 	list = {
		-- 		{ key = "u", action = "dir_up" },
		-- 	},
		-- },
	},
	renderer = {
		group_empty = true,
	},
	filters = {
		-- with this flag as false, dotfiles are visible
		dotfiles = false,
	},
	git = {
		ignore = false,
	},
})

vim.api.nvim_exec_autocmds('User', { pattern = 'nvim-tree' })
