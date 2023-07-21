local neotest = require("neotest")
neotest.setup({
   requires = {
    'haydenmeade/neotest-jest',
  },
	adapters = {
		require("neotest-python")({
			dap = { justMyCode = false, gevent = true },
			runner = "pytest",
			python = require("ebozkurt.helpers").get_python_path(vim.fn.getcwd()),
			-- args = {'--no-header', '--no-summary', '-q'},
			args = { "-s" },
		}),
		require("neotest-go")({}),
		require("neotest-jest")({
		}),
	},
})

vim.api.nvim_exec_autocmds("User", { pattern = "neotest" })
