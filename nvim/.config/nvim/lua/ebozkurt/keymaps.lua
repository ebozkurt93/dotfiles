vim.g.mapleader = ' '
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { noremap = true })
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', { noremap = true })
vim.keymap.set('n', '<leader>e', '<cmd>e!<cr>', { noremap = true })
vim.keymap.set('n', '<leader><C-q>', '<cmd>quitall!<cr>', { noremap = true })
-- vim.keymap.set('n', '<leader><CS-q>', '<cmd>qa!<cr>', {noremap = true})
vim.keymap.set('n', '<leader><space>', function()
	vim.cmd(':let @/ = ""')
	print " "
end, { desc = 'Clear search highlights' })
vim.keymap.set('n', '<leader>n', function()
	local current = vim.opt.relativenumber:get()
	for _, win_nr in ipairs(vim.api.nvim_list_wins()) do
		vim.wo[win_nr].relativenumber = not current
	end
end, { noremap = true })
vim.keymap.set('n', '<leader>sv', '<cmd>lua ReloadConfig()<cr>', { noremap = true, silent = false })
vim.keymap.set('n', '<leader>sV', function()
	vim.fn.system('source ~/.zshrc; nvim_remote_exec "<cmd>lua ReloadConfig()<cr>"')
end, { noremap = true, silent = false })

vim.keymap.set('n', '<leader>st', '<cmd>lua ReloadTheme()<cr>', { noremap = true, silent = false })

-- center things after jump
vim.keymap.set('n', '<C-u>', '<C-u>zz', { noremap = true })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { noremap = true })

vim.keymap.set('i', 'jk', '<ESC>', { noremap = true })
vim.keymap.set('v', 'jk', '<ESC>', { noremap = true })
-- keep cursor in same position after adding new line
vim.keymap.set('n', 'J', 'mzJ`z', { noremap = true })
-- keep copy register content same after paste
vim.keymap.set('x', '<leader>p', '"_dP', { noremap = true })
-- more center things after different type of jumps
vim.keymap.set('n', 'n', 'nzzzv', { noremap = true })
vim.keymap.set('n', 'N', 'Nzzzv', { noremap = true })
vim.api.nvim_create_autocmd('User', {
	pattern = 'IlluminateInitialized',
	callback = function()
		local illuminate = require('illuminate')
		vim.keymap.set('n', '<A-n>', function()
			illuminate.goto_next_reference(true)
			vim.cmd([[ :normal zz ]])
		end, { noremap = true })
		vim.keymap.set('n', '<A-p>', function()
			illuminate.goto_prev_reference(true)
			vim.cmd([[ :normal zz ]])
		end, { noremap = true })
	end
})
vim.api.nvim_create_autocmd('User', {
	pattern = 'IndentBlanklineInitialized',
	callback = function()
		vim.keymap.set('n', '<leader>i', '<cmd>:IndentBlanklineToggle<cr>', { noremap = true })
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'UfoInitialized',
	callback = function()
		vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
		vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
	end
})

-- keep selection after indentation
vim.cmd([[
:vnoremap < <gv
:vnoremap > >gv
]])

-- yank to clipboard
vim.keymap.set('v', '<leader>y', '"+y', { noremap = true })

-- move lines up/down
vim.keymap.set('n', '<A-j>', '<cmd>m .+1<cr>==', { noremap = true })
vim.keymap.set('n', '<A-k>', '<cmd>m .-2<cr>==', { noremap = true })
vim.cmd([[
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv
]])
-- this doesn't work for some reason, tries to do something on marks
-- vim.keymap.set('v', '<A-j>', "<cmd>m '>+1<cr>gv=gv", {noremap = true})
-- vim.keymap.set('v', '<A-k>', "<cmd>m '<-2<cr>gv=gv", {noremap = true})


vim.keymap.set('n', '<C-z>', '<cmd>set invwrap<cr>', { noremap = true })

-- window resizing
vim.keymap.set('n', '<SA-h>', '<cmd>:vertical resize -1<cr>', { noremap = true })
vim.keymap.set('n', '<SA-l>', '<cmd>:vertical resize +1<cr>', { noremap = true })
vim.keymap.set('n', '<SA-j>', '<cmd>:resize +1<cr>', { noremap = true })
vim.keymap.set('n', '<SA-k>', '<cmd>:resize -1<cr>', { noremap = true })

vim.keymap.set('n', '<leader><C-w>', '<cmd>WinShift<cr>', { noremap = true })

-- tabs
vim.keymap.set('n', 'tc', '<cmd>:tabnew<cr>', { noremap = true })
vim.keymap.set('n', 'ts', '<cmd>:tab split<cr>', { noremap = true })
vim.keymap.set('n', 'tn', '<cmd>:tabnext<cr>', { noremap = true })
vim.keymap.set('n', 'tp', '<cmd>:tabprev<cr>', { noremap = true })
vim.keymap.set('n', 'th', '<cmd>:-tabmove<cr>', { noremap = true })
vim.keymap.set('n', 'tl', '<cmd>:+tabmove<cr>', { noremap = true })

vim.keymap.set('n', '<leader>m', '<cmd>:TSContextToggle<cr>', { noremap = true })
vim.keymap.set('n', '<leader>u', '<cmd>:UndotreeShow<cr>', { noremap = true })
vim.keymap.set('n', '<leader>N', '<cmd>:Neogit<cr>', { noremap = true })

--telescope
vim.api.nvim_create_autocmd('User', {
	pattern = 'Telescope',
	callback = function()
		local builtin = require('telescope.builtin')
		local helpers = require('ebozkurt.helpers')
		vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
		vim.keymap.set('n', '<leader>fr', builtin.git_files, {})
		vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
		vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
		vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
		vim.keymap.set('n', '<leader>fj', builtin.jumplist, {})
		vim.keymap.set('n', '<leader>f.', helpers.find_files_nvim_config, {})
		vim.keymap.set('n', '<leader>f/', helpers.live_grep_nvim_config, {})
		vim.keymap.set('n', '<leader>ft', '<cmd>Telescope file_browser<cr>', {})
		vim.keymap.set('n', '<leader>fa', builtin.treesitter, {})
		vim.keymap.set('n', '<leader>fc', builtin.commands, {})
	end
})

-- LSP
vim.api.nvim_create_autocmd('User', {
	pattern = 'LspAttached',
	desc = 'LSP actions',
	callback = function()
		local bufopts = { noremap = true, silent = true, buffer = 0 }
		vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
		vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
		vim.keymap.set('n', 'gp', '<cmd>Lspsaga peek_definition<cr>', bufopts)
		vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, bufopts)
		vim.keymap.set('n', 'gh', '<cmd>Lspsaga lsp_finder<cr>', bufopts)
		vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
		vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, bufopts)
		vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
		vim.keymap.set('n', 'ca', '<cmd>Lspsaga code_action<cr>', bufopts)
		vim.keymap.set('v', 'ca', '<cmd>Lspsaga code_action<cr>', bufopts)
		vim.keymap.set('n', 'co', '<cmd>LSoutlineToggle<cr>', bufopts)
		--vim.keymap.set('n', 'gcr', vim.lsp.buf.clear_references, bufopts)
		vim.keymap.set('n', '<leader>dj', '<cmd>Lspsaga diagnostic_jump_prev<cr>', bufopts)
		vim.keymap.set('n', '<leader>dk', '<cmd>Lspsaga diagnostic_jump_next<cr>', bufopts)
		vim.keymap.set('n', '<leader>dl', '<cmd>Telescope diagnostics<cr>', bufopts)
		vim.keymap.set('n', '<leader>r', '<cmd>Lspsaga rename<cr>', bufopts)
		vim.keymap.set('n', '<leader>fs', function()
			vim.lsp.buf.format({ timeout_ms = 5000 })
		end, bufopts)
	end
})
vim.keymap.set('n', '<leader>ls', function ()
	vim.lsp.stop_client(vim.lsp.get_active_clients())
	print('All lsp servers stopped')
end, { noremap = true })
vim.keymap.set('n', '<leader>TC', function()
	require('ebozkurt.theme-gen').generate() end,
{noremap = true})
vim.keymap.set('n', '<leader>TS', function()
	require('ebozkurt.theme-gen').generate(vim.fn.input('Theme name: ')) end,
{noremap = true})

vim.keymap.set('n', '<leader>gh', '<cmd>:GHInteractive<cr>', { noremap = true })
vim.keymap.set('v', '<leader>gh', '<cmd>:GHInteractive<cr>', { noremap = true })

vim.api.nvim_create_autocmd('User', {
	pattern = 'lsplines',
	callback = function(event)
		vim.keymap.set('n', '<leader>l', function()
			local lsplines_enabled = event.data.enabled
			vim.diagnostic.config({ virtual_lines = not lsplines_enabled, virtual_text = lsplines_enabled })
			event.data.enabled = not event.data.enabled
		end, {})
	end
})

vim.keymap.set('n', '<leader>CC', function()
	if vim.api.nvim_get_option_value('colorcolumn', {}) == "" then
		for _, win_nr in ipairs(vim.api.nvim_list_wins()) do
			vim.wo[win_nr].colorcolumn = "80,120"
		end
	else
		for _, win_nr in ipairs(vim.api.nvim_list_wins()) do
			vim.wo[win_nr].colorcolumn = ""
		end
	end
end, {})

vim.api.nvim_create_autocmd('User', {
	pattern = 'gitsigns',
	callback = function(event)
		vim.keymap.set('n', '<leader>G', function()
			local default_branch = vim.fn.trim(vim.fn.system(
				"git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'"
			))
			local current_branch = vim.fn.trim(vim.fn.system(
				"git rev-parse --abbrev-ref HEAD"
			))
			local common_ancestor = vim.fn.trim(vim.fn.system(
				"git merge-base " .. default_branch .. " " .. current_branch
			))
			local value = event.data.value
			if value == 0 then
				require('gitsigns').change_base(common_ancestor, true)
				print('Changed gitsigns base to common ancestor node ' .. common_ancestor)
			elseif value == 1 then
				require('gitsigns').change_base(default_branch, true)
				print('Changed gitsigns base to ' .. default_branch)
			else
				require('gitsigns').change_base(nil, true)
				print('Resetted gitsigns base')
			end
			event.data.value = (event.data.value + 1) % 3
		end, {})
	end
})

--harpoon
vim.api.nvim_create_autocmd('User', {
	pattern = 'Harpoon',
	callback = function()
		local ui = require("harpoon.ui")
		local mark = require("harpoon.mark")
		vim.keymap.set('n', '<leader>h', function() ui.toggle_quick_menu() end, { noremap = true })
		vim.keymap.set('n', '<leader>a', function() mark.add_file() end, { noremap = true })
		vim.keymap.set('n', '<leader>1', function() ui.nav_file(1) end, { noremap = true })
		vim.keymap.set('n', '<leader>2', function() ui.nav_file(2) end, { noremap = true })
		vim.keymap.set('n', '<leader>3', function() ui.nav_file(3) end, { noremap = true })
		vim.keymap.set('n', '<leader>4', function() ui.nav_file(4) end, { noremap = true })
		vim.keymap.set('n', '<leader>5', function() ui.nav_file(5) end, { noremap = true })
	end
})

-- obsidian
vim.keymap.set('n', '<leader>os', '<cmd>ObsidianSearch<cr>', { noremap = true })
vim.keymap.set('n', '<leader>of', '<cmd>ObsidianQuickSwitch<cr>', { noremap = true })
vim.keymap.set('n', '<leader>oo', '<cmd>ObsidianOpen<cr>', { noremap = true })
vim.keymap.set('n', '<leader>og', '<cmd>ObsidianFollowLink<cr>', { noremap = true })
vim.keymap.set('n', '<leader>ot', '<cmd>ObsidianToday<cr>', { noremap = true })
-- quickfix
vim.keymap.set('n', '<leader>ck', '<cmd>cnext<cr>', { noremap = true })
vim.keymap.set('n', '<leader>cj', '<cmd>cprev<cr>', { noremap = true })
vim.keymap.set('n', '<leader>ce', '<cmd>copen<cr>', { noremap = true })
vim.keymap.set('n', '<leader>cc', '<cmd>cclose<cr>', { noremap = true })

-- nvim-tree
vim.api.nvim_create_autocmd('User', {
	pattern = 'nvim-tree',
	callback = function()
		local nt_api = require("nvim-tree.api")
		vim.keymap.set('n', '<C-p>', function() nt_api.tree.toggle() end, { noremap = true })
		vim.keymap.set('n', '<C-l>', function() nt_api.tree.toggle(true) end, { noremap = true })
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'possession',
	callback = function()
		local possession = require("nvim-possession")
        vim.keymap.set("n", "<leader>sl", function()
            possession.list()
        end)
        vim.keymap.set("n", "<leader>sn", function()
            possession.new()
        end)
        vim.keymap.set("n", "<leader>su", function()
            possession.update()
        end)
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'luasnip',
	callback = function()
		local ls = require("luasnip")
		vim.keymap.set({ 'i', 's' }, '<C-k>', function()
			if ls.expand_or_jumpable() then
				ls.expand_or_jump()
			end
		end, { silent = true })
		vim.keymap.set({ 'i', 's' }, '<C-j>', function()
			if ls.jumpable(-1) then
				ls.jump(-1)
			end
		end, { silent = true })
		vim.keymap.set({ 'i', 's' }, '<C-l>', function()
			if ls.choice_active() then
				ls.change_choice(1)
			end
		end, { silent = true })
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'trouble',
	callback = function()
		vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>",
			{ silent = true, noremap = true }
		)
		vim.keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>",
			{ silent = true, noremap = true }
		)
		vim.keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>",
			{ silent = true, noremap = true }
		)
		vim.keymap.set("n", "<leader>xl", "<cmd>TroubleToggle loclist<cr>",
			{ silent = true, noremap = true }
		)
		vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",
			{ silent = true, noremap = true }
		)
		vim.keymap.set("n", "gR", "<cmd>TroubleToggle lsp_references<cr>",
			{ silent = true, noremap = true }
		)
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'dap',
	callback = function()
		local dap = require('dap')
		local dapui = require('dapui')
		vim.keymap.set('n', '<F1>', function() dap.step_back() end, {})
		vim.keymap.set('n', '<F2>', function() dap.step_into() end, {})
		vim.keymap.set('n', '<F3>', function() dap.step_over() end, {})
		vim.keymap.set('n', '<F4>', function() dap.step_out() end, {})
		vim.keymap.set('n', '<F5>', function() dap.continue() end, {})
		vim.keymap.set('n', '<leader>b', function() dap.toggle_breakpoint() end, {})
		vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, {})
		vim.keymap.set('n', '<leader>lp', function() dap.set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end, {})
		vim.keymap.set('n', '<leader>dr', function() dap.repl.open() end, {})
		vim.keymap.set('n', '<leader>dt', function() dapui.toggle() end, {})
		vim.keymap.set('n', '<leader>df', function() require 'telescope'.extensions.dap.commands {} end, {})
	end
})

vim.api.nvim_create_autocmd('User', {
	pattern = 'neotest',
	callback = function()
		local neotest = require('neotest')
		vim.keymap.set('n', '<leader>tr', function() neotest.run.run() end, {})
		vim.keymap.set('n', '<leader>tR', function() neotest.run.run(vim.fn.expand("%")) end, {})
		vim.keymap.set('n', '<leader>td', function() neotest.run.run({ strategy = "dap" }) end, {})
		vim.keymap.set('n', '<leader>ts', function() neotest.run.stop() end, {})
		vim.keymap.set('n', '<leader>tt', function() neotest.summary.toggle() end, {})
		vim.keymap.set('n', '<leader>to', function() neotest.output.open() end, {})
		vim.keymap.set('n', '<leader>ta', function() neotest.run.attach() end, {})
	end
})
