-- todo: move all this content into subfolders and source them depending on the need





vim.opt.encoding = 'utf-8'
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = 'a'

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

vim.opt.wrap = true
vim.opt.breakindent = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4


vim.g.mapleader = ' '
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', {desc = 'Save'})
--vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', {desc = 'Quit'})
vim.keymap.set('n', '<leader><space>', function()
	vim.cmd(':let @/ = ""')
	print "Cleared search"
end, {desc = 'Clear search highlights'})
vim.keymap.set('n', '<leader>r', '<cmd>set invrelativenumber<cr>', {desc = 'Toggle relative line numbers'})
vim.keymap.set('n', '<leader>sv', '<cmd>source $MYVIMRC<cr>', {desc = 'Source neovim config'})


vim.keymap.set('i', 'jk', '<ESC>', {})

