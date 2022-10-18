require('possession').setup {
	autosave = {
        current = true,
        tmp = true,
        tmp_name = 'tmp',
        on_load = true,
        on_quit = true,
    },
}

vim.api.nvim_create_autocmd('User', {
	pattern = 'telescope+possession',
	callback = function()
		require('telescope').load_extension('possession') -- Load telescope
	end
})

vim.api.nvim_exec_autocmds('User', {pattern = 'possession'})

