local saga = require("lspsaga")

saga.init_lsp_saga({
	-- I've tried to comment out some of the defaults in nested tables
	finder_action_keys = {
		open = "o",
		vsplit = "v",
		split = "s",
		-- tabe = "t",
		quit = "q",
	},
	-- code_action_keys = {
	-- 	quit = "q",
	-- 	exec = "<CR>",
	-- },
	code_action_icon = "",
	code_action_lightbulb = {
		enable = false,
		enable_in_insert = true,
		cache_code_action = true,
		sign = true,
		update_time = 150,
		sign_priority = 20,
		virtual_text = true,
	},
	definition_action_keys = {
		-- edit = '<C-c>o',
		vsplit = '<C-c>v',
		split = '<C-c>s',
		-- tabe = '<C-c>t',
		-- quit = 'q',
	},
	symbol_in_winbar = {
		in_custom = true,
		enable = true,
		separator = ' ',
		show_file = true,
		-- define how to customize filename, eg: %:., %
		-- if not set, use default value `%:t`
		-- more information see `vim.fn.expand` or `expand`
		-- ## only valid after set `show_file = true`
		file_formatter = "",
		click_support = false,
	},
})
