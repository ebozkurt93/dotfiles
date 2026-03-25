require('ts_context_commentstring').setup({ enable_autocmd = false })

require('Comment').setup({
	---Add a space b/w comment and the line
	padding = true,
	---Whether the cursor should stay at its position
	sticky = true,
	---Lines to be ignored while (un)comment
	ignore = nil,
	---LHS of toggle mappings in NORMAL mode
	toggler = {
		---Line-comment toggle keymap
		line = 'gcc',
		---Block-comment toggle keymap
		block = 'gbc',
	},
	---LHS of operator-pending mappings in NORMAL and VISUAL mode
	opleader = {
		---Line-comment keymap
		line = 'gc',
		---Block-comment keymap
		block = 'gb',
	},
	---LHS of extra mappings
	extra = {
		---Add comment on the line above
		above = 'gcO',
		---Add comment on the line below
		below = 'gco',
		---Add comment at the end of line
		eol = 'gcA',
	},
	---Enable keybindings
	---NOTE: If given `false` then the plugin won't create any mappings
	mappings = {
		---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
		basic = true,
		---Extra mapping; `gco`, `gcO`, `gcA`
		extra = true,
	},
	---Function to call before (un)comment
	pre_hook = function(ctx)
		local ts_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()
		local ok, result = pcall(ts_hook, ctx)
		if ok and result then return result end
		-- On neovim 0.10+, vim.treesitter.get_parser returns nil (instead of
		-- raising) when no parser exists. Comment.nvim's ft.calculate doesn't
		-- guard against this and crashes. Bypass it by doing the lookup here.
		-- https://github.com/neovim/neovim/commit/fd1e019e90e76bb3f6236210ac6287f3b8d4d47f
		local ft = require('Comment.ft')
		return ft.get(vim.bo.filetype, ctx.ctype)
			or (vim.bo.commentstring ~= '' and vim.bo.commentstring or nil)
	end,

	---Function to call after (un)comment
	post_hook = nil,
})

local ft = require('Comment.ft')
ft.set('tool-versions', '#%s')
