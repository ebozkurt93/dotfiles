local neotest = require('neotest')
neotest.setup({
  adapters = {
    require("neotest-python")({
      dap = { justMyCode = true },
	  runner = "pytest",
	  python = require('ebozkurt.helpers').get_python_path(vim.fn.getcwd())
    }),
    require("neotest-go")({}),
  },
})

vim.api.nvim_exec_autocmds('User', {pattern = 'neotest'})
