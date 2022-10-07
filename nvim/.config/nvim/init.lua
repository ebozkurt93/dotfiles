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
vim.keymap.set('n', '<leader><space>', '<cmd>noh<cr>', {desc = 'Clear search highlights'})
vim.keymap.set('n', '<leader>r', '<cmd>set invrelativenumber<cr>', {desc = 'Toggle relative line numbers'})

