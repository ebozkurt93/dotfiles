local dap = require('dap')
local dapui = require('dapui')
-- used for opening dap related menus with telescope by default
require('telescope').load_extension('dap')

vim.api.nvim_exec_autocmds('User', {pattern = 'dap'})

dap.listeners.after.event_initialized["dapui_config"] = function()
	dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
	dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
	dapui.close()
end

require("dapui").setup()

-- language specific config
-- go install github.com/go-delve/delve/cmd/dlv@master
require('dap-go').setup(vim.keymap.set('n', '<leader>td', function() require('dap-go').debug_test() end, {}))

-- python -m venv ~/.local/share/virtualenvs/debugpy
-- ~/.local/share/virtualenvs/debugpy/bin/python -m pip install debugpy
-- relative paths do not work, therefore this
local exact_path = vim.fn.trim(vim.fn.system('cd ~/.local/share/virtualenvs/debugpy/bin/ && echo $PWD')) .. '/python'
local dap_python = require('dap-python')
dap_python.setup(exact_path, { pythonPath = require('ebozkurt.helpers').get_python_path(cwd) })
