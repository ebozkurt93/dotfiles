P = function(v)
	print(vim.inspect(v))
	return v
end

local M = {}

--apparently vim.tbl_extend() does the same thing with more options
--function M.merge(...)
--  local result = {}
--  for _, t in ipairs{...} do
--    for k, v in pairs(t) do
--      result[k] = v
--    end
--    local mt = getmetatable(t)
--    if mt then
--      setmetatable(result, mt)
--    end
--  end
--  return result
--end

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
group = vim.api.nvim_create_augroup('renameTmuxWindow', {clear = true})
vim.api.nvim_create_autocmd('VimEnter', {
	callback = function ()
		local path = vim.fs.basename(vim.fn.getcwd())
		vim.fn.system('tmux setw automatic-rename off')
		vim.fn.system('tmux rename-window ' .. path)
	end,
	group = group
})
vim.api.nvim_create_autocmd('VimLeave', {
	callback = function ()
		vim.fn.system('tmux setw automatic-rename on')
	end,
	group = group
})

return M


