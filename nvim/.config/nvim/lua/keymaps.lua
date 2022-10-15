vim.g.mapleader = ' '
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', {noremap = true})
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', {noremap = true})
vim.keymap.set('n', '<leader>e', '<cmd>e!<cr>', {noremap = true})
vim.keymap.set('n', '<leader><C-q>', '<cmd>quitall<cr>', {noremap = true})
vim.keymap.set('n', '<leader><CS-q>', '<cmd>qa!<cr>', {noremap = true})
vim.keymap.set('n', '<leader><space>', function()
	vim.cmd(':let @/ = ""')
	print "Cleared search"
end, {desc = 'Clear search highlights'})
vim.keymap.set('n', '<leader>r', '<cmd>set invrelativenumber<cr>', {noremap = true})
-- vim.keymap.set('n', '<leader>sv', '<cmd>source $MYVIMRC<cr>', {desc = 'Source neovim config', noremap = true})
vim.keymap.set('n', '<leader>sv', '<cmd>lua ReloadConfig()<cr>', {noremap = true, silent = false})

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


-- todo: find a better keybinding for this
vim.keymap.set('n', '<C-z>', '<cmd>set invwrap<cr>', {noremap = true})

-- window resizing
-- todo: not sure about these keymaps, go over these later
vim.keymap.set('n', '<SCA-h>', '<cmd>:vertical resize -1<cr>', {noremap = true})
vim.keymap.set('n', '<SCA-l>', '<cmd>:vertical resize +1<cr>', {noremap = true})
vim.keymap.set('n', '<SCA-j>', '<cmd>:resize +1<cr>', {noremap = true})
vim.keymap.set('n', '<SCA-k>', '<cmd>:resize -1<cr>', {noremap = true})

--telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', 'ff', builtin.find_files, {})
vim.keymap.set('n', 'fg', builtin.live_grep, {})
vim.keymap.set('n', 'fb', builtin.buffers, {})
vim.keymap.set('n', 'fh', builtin.help_tags, {})



