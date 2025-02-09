vim.opt.encoding = 'utf-8'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ruler = true
vim.opt.mouse = 'a'
vim.opt.modelines = 0
vim.opt.belloff = 'all'
vim.opt.swapfile = false
vim.opt.modifiable = true
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

vim.cmd [[
	autocmd BufNewFile,BufRead *.zshrc set filetype=zsh
	autocmd BufNewFile,BufRead *.tfvars set filetype=hcl
	autocmd BufNewFile,BufRead *.jsonl set filetype=json
]]

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

-- whitespace
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.tabstop = 4
-- vim.opt.shiftwidth = 4
vim.opt.list = false

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

vim.opt.signcolumn = 'auto:5'
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

vim.o.foldcolumn = '0'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.foldmethod = 'syntax'
-- vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
