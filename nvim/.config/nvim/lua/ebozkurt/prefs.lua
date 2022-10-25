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
vim.opt.colorcolumn = {80, 120}
-- vim.opt.title = true
-- vim.opt.titlestring='%{expand(\"%:p:h\")}'

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
vim.opt.listchars:append({eol = '¬'})
vim.opt.listchars:append({tab = '→ '})
vim.opt.listchars:append({trail = '·'})
vim.opt.listchars:append({extends = '…'})
vim.opt.listchars:append({precedes = '…'})

-- windows/splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- statusbar
vim.opt.laststatus = 2
vim.api.nvim_create_autocmd('User', {
	pattern = 'LuaLineInitialized',
	callback = function()
		vim.opt.showmode = false
	end
})

vim.opt.signcolumn = 'auto'
vim.opt.completeopt = {'menu', 'menuone', 'noselect'}

--vim.opt.foldlevel = 1
--vim.opt.foldmethod = "expr"
vim.opt.foldmethod = "expr"
vim.opt.foldlevel = 3
