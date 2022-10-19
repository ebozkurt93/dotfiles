local execute = vim.api.nvim_command
-- ensure that packer is installed
local install_path = vim.fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
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
  use { 'nvim-telescope/telescope.nvim', tag = '0.1.0', requires = { { 'nvim-lua/plenary.nvim'} } }
  use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  use { "nvim-telescope/telescope-file-browser.nvim" }
  use 'L3MON4D3/LuaSnip'

  use { 'nvim-treesitter/nvim-treesitter', run = function() require('nvim-treesitter.install').update({ with_sync = true }) end, }
  use { 'nvim-treesitter/playground' }

  -- lsp and autocompletion
  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-nvim-lua'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-cmdline'
  use 'saadparwaiz1/cmp_luasnip'
  --use 'tjdevries/nlua.nvim'
  use 'nvim-lua/completion-nvim'
  use 'onsails/lspkind.nvim'

  use { 'numToStr/Comment.nvim', config = function() require('Comment').setup() end }
  --use { 'nvim-lualine/lualine.nvim', requires = { 'kyazdani42/nvim-web-devicons', opt = true }}
  use { 'nvim-lualine/lualine.nvim' }
  use { 'nvim-tree/nvim-tree.lua',
  requires = {
    'nvim-tree/nvim-web-devicons', -- optional, for file icons
  }, }
  use { 'ThePrimeagen/harpoon', requires = { { 'nvim-lua/plenary.nvim'} } }
  use 'NvChad/nvim-colorizer.lua'
  use { 'jedrzejboczar/possession.nvim', requires = { 'nvim-lua/plenary.nvim' } }
  use 'tpope/vim-surround'

  -- themes
  use 'ellisonleao/gruvbox.nvim'
  use 'Shatur/neovim-ayu'
  use 'shaunsingh/nord.nvim'
  use 'folke/tokyonight.nvim'
  use { "catppuccin/nvim", as = "catppuccin" }
  end
)

