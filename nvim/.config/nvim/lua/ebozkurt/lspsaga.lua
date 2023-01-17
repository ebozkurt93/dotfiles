local saga = require("lspsaga")

saga.setup({
	request_timeout = 10000,
	lightbulb = {
		enable = false,
	},
	symbol_in_winbar = {
		enable = false,
	},
})
