local actions = require "telescope.actions"
local action_layout = require "telescope.actions.layout"

local shared_keys = {
	['<C-p>'] = action_layout.toggle_preview,
	['<C-o>'] = action_layout.toggle_mirror,
	['<C-d>'] = actions.delete_buffer,
	['<C-f>'] = actions.to_fuzzy_refine
}

local picker_options = {
	-- todo: set hidden back to false when you enable searching all git files
	hidden = true,
	follow = true,
	no_ignore = true,
}

require('telescope').setup {
	defaults = {
		-- Default configuration for telescope goes here:
		-- config_key = value,
		--prompt_prefix = ' >',
		--file_previewer = require("telescope.previewers").vim_buffer_cat.new,
		--grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
		--qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
		-- default sorters were `get_fzy_sorter`, however these feel better
		file_sorter = require('telescope.sorters').get_fuzzy_file,
		-- generic_sorter = require('telescope.sorters').get_generic_fuzzy_sorter,
		file_ignore_patterns = {
			'node_modules/',
			'.git/',
			'.git-crypt/',
			'.idea/',
			'dist/',
			'target/'
		},
		sorting_strategy = 'ascending',
		layout_config = {
			prompt_position = 'top',
		},
		color_devicons = false, -- sadly this doesn't help disable icons in find_files
		wrap_results = true,
		mappings = {
			i = vim.tbl_extend('force', shared_keys, {
				["<C-h>"] = "which_key",
			}),
			n = shared_keys
		},
	},
	pickers = {
		find_files = picker_options,
		live_grep = vim.tbl_extend('force', picker_options, { additional_args = function(opts)
			return { "--hidden" }
		end }),
		jumplist = vim.tbl_extend('force', picker_options, { fname_width = 70 }),
		-- Default configuration for builtin pickers goes here:
		-- picker_name = {
		--   picker_config_key = value,
		--   ...
		-- }
		-- Now the picker_config_key will be applied every time you call this
		-- builtin picker
	},
	extensions = {
		file_browser = {
			theme = 'ivy',
			hijack_netrw = true,
			mappings = {
				['i'] = shared_keys,
				['n'] = shared_keys,
			}
		},
		-- Your extension configuration goes here:
		-- extension_name = {
		--   extension_config_key = value,
		-- }
		-- please take a look at the readme of the extension you want to configure
	}
}

require('telescope').load_extension('fzf')
require('telescope').load_extension('file_browser')

vim.api.nvim_exec_autocmds('User', { pattern = 'Telescope' })
