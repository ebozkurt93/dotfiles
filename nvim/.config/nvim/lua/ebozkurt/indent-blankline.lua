-- these are coming from 'rainbow-delimiters.nvim'
local highlight = {
	"RainbowDelimiterRed",
	"RainbowDelimiterYellow",
	"RainbowDelimiterBlue",
	"RainbowDelimiterOrange",
	"RainbowDelimiterGreen",
	"RainbowDelimiterViolet",
	"RainbowDelimiterCyan",
}

-- local c = "▕"
local c = "┊"
require("ibl").setup({
	indent = {
		char = c,
		tab_char = c,
		smart_indent_cap = false,
		highlight = highlight,
	},
	scope = { enabled = true, highlight = highlight },
})

local hooks = require "ibl.hooks"
hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)

vim.api.nvim_exec_autocmds('User', { pattern = 'IndentBlanklineInitialized' })
