local action_layout = require "telescope.actions.layout"
local previewers = require("telescope.previewers")

require('telescope').load_extension('fzf')
require('telescope').load_extension('file_browser')

local shared_keys = {
	["<C-p>"] = action_layout.toggle_preview,
	["<C-o>"] = action_layout.toggle_mirror,
}

require('telescope').setup{
  defaults = {
    -- Default configuration for telescope goes here:
    -- config_key = value,
	--prompt_prefix = ' >',
	--file_previewer = require("telescope.previewers").vim_buffer_cat.new,
	--grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
	--qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
	layout_config = {
		prompt_position = 'top',
	},
    mappings = {
      i = vim.tbl_extend('force', shared_keys, {
        ["<C-h>"] = "which_key",
	  }),
      n = shared_keys
    }
  },
  pickers = {
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
	  }
    -- Your extension configuration goes here:
    -- extension_name = {
    --   extension_config_key = value,
    -- }
    -- please take a look at the readme of the extension you want to configure
  }
}

