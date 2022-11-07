P = function(v)
	print(vim.inspect(v))
	return v
end

local M = {}

local nvim_conf_dir = '~/.config/nvim/'
local builtin = require('telescope.builtin')
function M.find_files_nvim_config()
	builtin.find_files({
		prompt_title = 'nvim config - files',
		cwd = nvim_conf_dir,
	})
end
function M.live_grep_nvim_config()
	builtin.live_grep({
		prompt_title = 'nvim config - grep',
		cwd = nvim_conf_dir,
	})
end

-- Change tmux window title based on vim project
-- local group = vim.api.nvim_create_augroup('renameTmuxWindow', {clear = true})
-- vim.api.nvim_create_autocmd('VimEnter', {
-- 	callback = function ()
-- 		local path = vim.fs.basename(vim.fn.getcwd())
-- 		vim.fn.system('tmux setw automatic-rename off')
-- 		vim.fn.system('tmux rename-window ' .. path)
-- 	end,
-- 	group = group
-- })
-- vim.api.nvim_create_autocmd('VimLeave', {
-- 	callback = function ()
-- 		vim.fn.system('tmux setw automatic-rename on')
-- 	end,
-- 	group = group
-- })
function M.get_python_path(workspace)
	local path = require('lspconfig/util').path
	-- Use activated virtualenv.
	if vim.env.VIRTUAL_ENV then
		return path.join(vim.env.VIRTUAL_ENV, 'bin', 'python')
	end

	-- Find and use virtualenv from pipenv in workspace directory.
	local match = vim.fn.glob(path.join(workspace, 'Pipfile'))
	if match ~= '' then
		local venv = vim.fn.trim(vim.fn.system('PIPENV_PIPFILE=' .. match .. ' pipenv --venv'))
		return path.join(venv, 'bin', 'python')
	end

	-- Find and use virtualenv in workspace directory.
	for _, pattern in ipairs({ '*', '.*' }) do
		match = vim.fn.glob(path.join(workspace, pattern, 'pyvenv.cfg'))
		if match ~= '' then
			return path.join(path.dirname(match), 'bin', 'python')
		end
	end
	if exepath == nil then
		return ''
	end

	-- Fallback to system Python.
	return exepath('python3') or exepath('python') or 'python'
end

return M

