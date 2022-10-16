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
vim.keymap.set('n', '<leader>n', function()
	local current = vim.opt.relativenumber:get()
	vim.opt.relativenumber = not current
end, {noremap = true})
vim.keymap.set('n', '<leader>sv', '<cmd>lua ReloadConfig()<cr>', {noremap = true, silent = false})

-- center things after jump
vim.keymap.set('n', '<C-u>', '<C-u>zz', {noremap = true})
vim.keymap.set('n', '<C-d>', '<C-d>zz', {noremap = true})

vim.keymap.set('i', 'jk', '<ESC>', {noremap = true})

-- yank to clipboard
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
local helpers = require('ebozkurt.helpers')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
vim.keymap.set('n', '<leader>fj', builtin.jumplist, {})
vim.keymap.set('n', '<leader>f.', helpers.find_files_nvim_config, {})
vim.keymap.set('n', '<leader>f/', helpers.live_grep_nvim_config, {})
vim.keymap.set('n', '<leader>ft', '<cmd>Telescope file_browser<cr>', {})

-- LSP
vim.api.nvim_create_autocmd('User', {
	pattern = 'LspAttached',
    desc = 'LSP actions',
	callback = function()
	  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
	  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
	  vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, bufopts)
	  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
	  vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, bufopts)
	  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
	  --vim.keymap.set('n', 'gcr', vim.lsp.buf.clear_references, bufopts)
	  vim.keymap.set('n', '<leader>dj', vim.diagnostic.goto_next, bufopts)
	  vim.keymap.set('n', '<leader>dk', vim.diagnostic.goto_prev, bufopts)
	  vim.keymap.set('n', '<leader>dl', '<cmd>Telescope diagnostics<cr>', bufopts)
	  vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename, bufopts)
	end
})

-- quickfix
vim.keymap.set('n', '<leader>ck', '<cmd>cnext<cr>', {noremap = true})
vim.keymap.set('n', '<leader>cj', '<cmd>cprev<cr>', {noremap = true})
vim.keymap.set('n', '<leader>ce', '<cmd>copen<cr>', {noremap = true})
vim.keymap.set('n', '<leader>cc', '<cmd>cclose<cr>', {noremap = true})

