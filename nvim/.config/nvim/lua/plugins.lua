local vim = vim
local execute = vim.api.nvim_command
local fn = vim.fn
-- ensure that packer is installed
local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
    execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
    execute 'packadd packer.nvim'
end
vim.cmd('packadd packer.nvim')
local packer = require'packer'
local util = require'packer.util'
packer.init({
  package_root = util.join_paths(vim.fn.stdpath('data'), 'site', 'pack')
})
--- startup and add configure plugins
packer.startup(function(use)
  -- add you plugins here like:
  -- use 'neovim/nvim-lspconfig'
  use { 'ellisonleao/gruvbox.nvim' }
  use { 'Shatur/neovim-ayu' }
  --use { 'Shatur/neovim-ayu', commit = 'bae6314522e47172564203d4f1c56dc1e39c1c14' }
  use { 'nvim-telescope/telescope.nvim', tag = '0.1.0', requires = { {'nvim-lua/plenary.nvim'} }
}
  end
)
