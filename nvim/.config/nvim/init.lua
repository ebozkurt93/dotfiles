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

-- center things after jump
vim.keymap.set('n', '<C-u>', '<C-u>zz', {noremap = true})
vim.keymap.set('n', '<C-d>', '<C-d>zz', {noremap = true})

vim.keymap.set('i', 'jk', '<ESC>', {noremap = true})

-- yank to clipboard
vim.keymap.set('v', '<leader>y', '"+y', {noremap = true})
vim.keymap.set('v', '<leader>y', '"+y', {noremap = true})

-- move lines up/down
vim.keymap.set('n', '<A-j>', '<cmd>m .+1<cr>==', {noremap = true})
vim.keymap.set('n', '<A-k>', '<cmd>m .-2<cr>==', {noremap = true})
vim.cmd([[
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv
]])
-- this doesn't work for some reason, tries to do something on marks
-- vim.keymap.set('v', '<A-j>', "<cmd>m '>+1<cr>gv=gv", {noremap = true})
-- vim.keymap.set('v', '<A-k>', "<cmd>m '<-2<cr>gv=gv", {noremap = true})



