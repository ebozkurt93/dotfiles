local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--single-branch",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.runtimepath:prepend(lazypath)

--- startup and add configure plugins
require("lazy").setup({
	{ "nvim-telescope/telescope.nvim", dependencies = { { "nvim-lua/plenary.nvim" } } },
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	{ "nvim-telescope/telescope-file-browser.nvim" },
	"L3MON4D3/LuaSnip",

	{
		"nvim-treesitter/nvim-treesitter",
		build = function()
			require("nvim-treesitter.install").update({ with_sync = true })
		end,
	},
	{ "nvim-treesitter/playground" },
	"nvim-treesitter/nvim-treesitter-context",

	-- lsp and autocompletion
	"neovim/nvim-lspconfig",
	"hrsh7th/nvim-cmp",
	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-nvim-lua",
	"hrsh7th/cmp-path",
	"hrsh7th/cmp-buffer",
	"hrsh7th/cmp-cmdline",
	"saadparwaiz1/cmp_luasnip",
	"rafamadriz/friendly-snippets",
	--use 'tjdevries/nlua.nvim'
	"nvim-lua/completion-nvim",
	"onsails/lspkind.nvim",
	"windwp/nvim-autopairs",
	"windwp/nvim-ts-autotag",
	{
		"nvimdev/lspsaga.nvim",
		event = "LspAttach",
		dependencies = "nvim-treesitter/nvim-treesitter",
	},
	{ url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim" },
	{ "williamboman/mason.nvim" },
	{ "williamboman/mason-lspconfig.nvim" },
	{ "jose-elias-alvarez/null-ls.nvim", dependencies = "nvim-lua/plenary.nvim" },
	{ "j-hui/fidget.nvim", branch = "legacy" },

	{
		"zbirenbaum/copilot.lua",
		enabled = function()
			local isCopilotEnabled = os.getenv("COPILOT_ENABLED") == "true"
			local path = os.getenv("COPILOT_ENABLED_PATH")

			-- dash(-) is a pattern variable for lua, therefore it needs to be escaped
			local function escape_magic(s)
				return (s:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1'))
			end

			return isCopilotEnabled and path ~= nil and path ~= "" and string.match(vim.fn.getcwd(), escape_magic(path))
		end,
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
			})
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		config = function()
			require("copilot_cmp").setup()
		end,
	},
	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	},
	"JoosepAlviste/nvim-ts-context-commentstring",

	--use { 'nvim-lualine/lualine.nvim', dependencies = { 'kyazdani42/nvim-web-devicons', opt = true }}
	{ "nvim-lualine/lualine.nvim" },
	{
		"nvim-tree/nvim-tree.lua",
		-- this might be needed for the icons displayed etc
		-- curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
		-- dependencies = {
		-- 	"nvim-tree/nvim-web-devicons", -- optional, for file icons
		-- },
	},
	{ "ThePrimeagen/harpoon", dependencies = { { "nvim-lua/plenary.nvim" } } },
	"chentoast/marks.nvim",

	"NvChad/nvim-colorizer.lua",
	{
		"lukas-reineke/virt-column.nvim",
		config = function()
			require("virt-column").setup({ char = "▕" })
		end,
	},

	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
	"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically

	{ "gennaro-tedesco/nvim-possession", dependencies = { "ibhagwan/fzf-lua" } },
	"tpope/vim-surround",
	{ "kevinhwang91/nvim-ufo", dependencies = "kevinhwang91/promise-async" },

	"lewis6991/gitsigns.nvim",
	{ "TimUntersberger/neogit", dependencies = "nvim-lua/plenary.nvim" },
	"tpope/vim-fugitive",
	"ruanyl/vim-gh-line",
	{ "sindrets/diffview.nvim", dependencies = "nvim-lua/plenary.nvim" },

	{ "folke/trouble.nvim", dependencies = "kyazdani42/nvim-web-devicons" },
	{ "folke/which-key.nvim" },

	{ "folke/todo-comments.nvim", dependencies = "nvim-lua/plenary.nvim" },

	"sindrets/winshift.nvim",
	{
		"folke/twilight.nvim",
		config = function()
			require("twilight").setup({})
		end,
	},
	{
		"folke/zen-mode.nvim",
		config = function()
			require("zen-mode").setup({})
		end,
	},

	{ "epwalsh/obsidian.nvim", dependencies = "nvim-lua/plenary.nvim" },

	-- debugging
	"mfussenegger/nvim-dap",
	{ "rcarriga/nvim-dap-ui", dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" } },
	"leoluz/nvim-dap-go",
	"mfussenegger/nvim-dap-python",
	"theHamsta/nvim-dap-virtual-text",
	"nvim-telescope/telescope-dap.nvim",

	-- testing
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"antoinemadec/FixCursorHold.nvim",
		},
	},
	"nvim-neotest/neotest-python",
	"nvim-neotest/neotest-go",
	"haydenmeade/neotest-jest",

	"RRethy/vim-illuminate",
	"p00f/nvim-ts-rainbow",
	{ url = "https://gitlab.com/HiPhish/rainbow-delimiters.nvim" },
	"mbbill/undotree",

	{ "kevinhwang91/nvim-bqf" },

	"dbeniamine/cheat.sh-vim",

	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			{ "tpope/vim-dadbod", lazy = true },
			{ "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
		},
		cmd = {
			"DBUI",
			"DBUIToggle",
			"DBUIAddConnection",
			"DBUIFindBuffer",
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_win_position = "right"
		end,
	},
	{
		'stevearc/oil.nvim',
		opts = {},
	},

	-- themes
	"ellisonleao/gruvbox.nvim",
	"ayu-theme/ayu-vim",
	"shaunsingh/nord.nvim",
	"folke/tokyonight.nvim",
	{ "catppuccin/nvim", name = "catppuccin" },
	{ "rose-pine/neovim", name = "rose-pine" },
	"kvrohit/mellow.nvim",
	"sainnhe/everforest",
	-- use {'shaunsingh/oxocarbon.nvim', branch = 'fennel'}
	"B4mbus/oxocarbon-lua.nvim",
	"Yazeed1s/oh-lucy.nvim",
	"EdenEast/nightfox.nvim",
	"savq/melange",
	"rebelot/kanagawa.nvim",
	"haishanh/night-owl.vim",
	"AlexvZyl/nordic.nvim",
	"olivercederborg/poimandres.nvim",
	"arturgoms/moonbow.nvim",
	{
		"projekt0n/github-nvim-theme",
		config = function()
			require("github-theme").setup({})
		end,
	},
	"projekt0n/caret.nvim",
	"xiyaowong/transparent.nvim",
	"xero/miasma.nvim",
})
