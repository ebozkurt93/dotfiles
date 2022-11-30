require('gitsigns').setup({
	current_line_blame = true,
})
vim.api.nvim_exec_autocmds('User', { pattern = 'gitsigns', data = { value = 0 } })
