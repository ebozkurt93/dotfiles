require("nvim-possession").setup({
    autosave = false,
	fzf_winopts = {
        -- any valid fzf-lua winopts options, for instance
        width = 0.9,
        preview = {
            vertical = "right:60%"
        }
    }
})

vim.api.nvim_exec_autocmds('User', {pattern = 'possession'})

