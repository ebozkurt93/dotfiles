local execute = vim.api.nvim_command
-- ensure that packer is installed
local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/opt/packer.nvim'
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
	execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
	execute 'packadd packer.nvim'
end
vim.cmd('packadd packer.nvim')
local packer = require 'packer'
local util = require 'packer.util'
packer.init({
	package_root = util.join_paths(vim.fn.stdpath('data'), 'site', 'pack')
})
--- startup and add configure plugins
packer.startup(function(use)
	use { 'nvim-telescope/telescope.nvim', tag = '0.1.0', requires = { { 'nvim-lua/plenary.nvim' } } }
	use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
	use { "nvim-telescope/telescope-file-browser.nvim" }
	use 'L3MON4D3/LuaSnip'

	use { 'nvim-treesitter/nvim-treesitter',
		run = function() require('nvim-treesitter.install').update({ with_sync = true }) end, }
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
	use 'windwp/nvim-autopairs'
	use({ "glepnir/lspsaga.nvim", branch = "main" })

	use { 'numToStr/Comment.nvim', config = function() require('Comment').setup() end }
	--use { 'nvim-lualine/lualine.nvim', requires = { 'kyazdani42/nvim-web-devicons', opt = true }}
	use { 'nvim-lualine/lualine.nvim' }
	use { 'nvim-tree/nvim-tree.lua',
		-- this might be needed for the icons displayed etc
		-- curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
		requires = {
			'nvim-tree/nvim-web-devicons', -- optional, for file icons
		}, }
	use { 'ThePrimeagen/harpoon', requires = { { 'nvim-lua/plenary.nvim' } } }

	use 'NvChad/nvim-colorizer.lua'
	use "xiyaowong/virtcolumn.nvim"

	use { 'jedrzejboczar/possession.nvim', requires = { 'nvim-lua/plenary.nvim' } }
	use 'tpope/vim-surround'
	use 'lewis6991/gitsigns.nvim'
	use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim', commit = '691cf89f59ed887809db7854b670cdb944dc9559' }
	use 'tpope/vim-fugitive'
	use 'ruanyl/vim-gh-line'

	use { "folke/trouble.nvim", requires = "kyazdani42/nvim-web-devicons" }
	use { "folke/which-key.nvim" }

	use { "folke/todo-comments.nvim", requires = "nvim-lua/plenary.nvim" }

	-- debugging
	use 'mfussenegger/nvim-dap'
	use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }
	use 'leoluz/nvim-dap-go'
	use 'mfussenegger/nvim-dap-python'
	use 'theHamsta/nvim-dap-virtual-text'
	use 'nvim-telescope/telescope-dap.nvim'

	-- testing
	use { "nvim-neotest/neotest",
		requires = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"antoinemadec/FixCursorHold.nvim"
		}
	}
	use 'nvim-neotest/neotest-python'
	use 'nvim-neotest/neotest-go'

	use 'RRethy/vim-illuminate'
	use 'p00f/nvim-ts-rainbow'

	use {'kevinhwang91/nvim-bqf'}

	-- themes
	use 'ellisonleao/gruvbox.nvim'
	use 'Shatur/neovim-ayu'
	use 'shaunsingh/nord.nvim'
	use 'folke/tokyonight.nvim'
	use { "catppuccin/nvim", as = "catppuccin" }
	use { 'rose-pine/neovim', as = 'rose-pine' }
	use 'kvrohit/mellow.nvim'
	use 'sainnhe/everforest'
end
)
