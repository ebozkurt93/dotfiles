-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
      },
    },
  },
  renderer = {
    group_empty = true,
	-- icons = {
	-- do not have the fonts installed, therefore disabling the icons as well
	-- show = {
	-- 	file = false,
	-- 	folder = false,
	-- 	folder_arrow = false,
	-- }
	-- },
  },
  filters = {
	-- with this flag as false, dotfiles are visible
    dotfiles = false,
  },
  git = {
	  ignore = false,
  },
})

vim.api.nvim_exec_autocmds('User', {pattern = 'nvim-tree'})
