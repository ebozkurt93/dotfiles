local action_layout = require "telescope.actions.layout"
local previewers = require("telescope.previewers")

require('telescope').load_extension('fzf')
require('telescope').load_extension('file_browser')

local function merge(...)
  local result = {}
  for _, t in ipairs{...} do
    for k, v in pairs(t) do
      result[k] = v
    end
    local mt = getmetatable(t)
    if mt then
      setmetatable(result, mt)
    end
  end
  return result
end

require('telescope').setup{
  defaults = {
    -- Default configuration for telescope goes here:
    -- config_key = value,
	--prompt_prefix = ' >',
	--file_previewer = require("telescope.previewers").vim_buffer_cat.new,
	--grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
	--qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    mappings = {
      i = {
        -- map actions.which_key to <C-h> (default: <C-/>)
        -- actions.which_key shows the mappings for your picker,
        -- e.g. git_{create, delete, ...}_branch for the git_branches picker
        ["<C-h>"] = "which_key",
		-- this seems to be done by default
        --["<C-q>"] = actions.send_to_fqlist,
        ["<C-p>"] = action_layout.toggle_preview,
        ["<C-o>"] = action_layout.toggle_mirror,
      },
      n = {
        ["<C-p>"] = action_layout.toggle_preview,
        ["<C-o>"] = action_layout.toggle_mirror,
      }
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
			  ['i'] = {
					["<C-p>"] = action_layout.toggle_preview,
					["<C-o>"] = action_layout.toggle_mirror,
			  }
		  }
	  }
    -- Your extension configuration goes here:
    -- extension_name = {
    --   extension_config_key = value,
    -- }
    -- please take a look at the readme of the extension you want to configure
  }
}

