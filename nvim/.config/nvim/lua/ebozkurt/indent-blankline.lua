require("indent_blankline").setup({
	char = "┊",
	space_char_blankline = " ",
	show_current_context = true,
	show_end_of_line = false,
	show_trailing_blankline_indent = false,
	indent_blankline_show_first_indent_level = false,
	show_current_context_start = false,
	indent_blankline_strict_tabs = true,
})
vim.api.nvim_exec_autocmds('User', { pattern = 'IndentBlanklineInitialized' })
