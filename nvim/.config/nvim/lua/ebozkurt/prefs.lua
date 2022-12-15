vim.opt.encoding = 'utf-8'
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.ruler = true
vim.opt.mouse = 'a'
-- todo: check what this does, I've copied this from my previous config but not sure I really understand
vim.opt.modelines = 0
vim.opt.belloff = 'all'
vim.opt.swapfile = false
vim.opt.modifiable = true
vim.opt.colorcolumn = { 80, 120 }
-- vim.opt.title = true
-- vim.opt.titlestring='%{expand(\"%:p:h\")}'

vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.backup = true
vim.opt.backupdir = os.getenv("HOME") .. "/.vim/backups//"

vim.api.nvim_create_autocmd('BufWritePre', {
	pattern = '*',
	group = vim.api.nvim_create_augroup('timestamp_backupext', { clear = true }),
	desc = 'Add timestamp to backup extension',
	callback = function()
		vim.opt.backupext = '-' .. vim.fn.strftime('%Y%m%d%H%M%S')
	end,
})


-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

-- whitespace
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.list = true

--vim.opt.listchars:append({eol = '↵'})
vim.opt.listchars:append({ eol = '¬' })
vim.opt.listchars:append({ tab = '→ ' })
vim.opt.listchars:append({ trail = '·' })
vim.opt.listchars:append({ extends = '…' })
vim.opt.listchars:append({ precedes = '…' })
vim.opt.listchars:append({ leadmultispace = '·' })

-- windows/splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- statusbar
vim.opt.laststatus = 2
--vim.api.nvim_del_augroup_by_name('my_lualine')
local group = vim.api.nvim_create_augroup('my_lualine', { clear = true })
vim.api.nvim_create_autocmd('User', {
	pattern = 'LuaLineInitialized',
	callback = function()
		vim.opt.showmode = false
		-- For some reason lualine overrides showtabline setting globally, this is used to undo those changes
		vim.api.nvim_create_autocmd('VimEnter', {
			callback = function()
				vim.opt.showtabline = 1
			end,
		})
		vim.api.nvim_create_autocmd('User', {
			pattern = 'ReloadConfig',
			callback = function()
				vim.opt.showtabline = 1
			end,
		})
	end,
	group = group
})

vim.opt.signcolumn = 'auto'
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

--vim.opt.foldlevel = 1
--vim.opt.foldmethod = "expr"
vim.opt.foldmethod = "expr"
vim.opt.foldlevel = 3
