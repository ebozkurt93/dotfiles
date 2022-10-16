vim.opt.encoding = 'utf-8'
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.ruler = true
vim.opt.mouse = 'a'
-- todo: check what this does, I've copied this from my previous config but not sure I really understand
vim.opt.modelines = 0
vim.opt.belloff = 'all'
--vim.opt.colorcolumn = {80, 120}

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

-- statusbar
vim.opt.laststatus = 2

vim.opt.signcolumn = 'auto'
vim.opt.completeopt = {'menu', 'menuone', 'noselect'}

--vim.opt.foldlevel = 1
--vim.opt.foldmethod = "expr"
