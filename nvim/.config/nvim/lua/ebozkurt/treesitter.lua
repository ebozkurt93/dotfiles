require("nvim-treesitter.configs").setup({
	-- A list of parser names, or "all"
	ensure_installed = {
		"python",
		"go",
		"javascript",
		"html",
		"typescript",
		"sql",
		"graphql",
		"bash",
		"lua",
		"rust",
		"markdown",
		"proto",
		"hcl",
		"yaml",
		"vim",
		"vimdoc",
	},

	-- Install parsers synchronously (only applied to `ensure_installed`)
	sync_install = false,

	-- Automatically install missing parsers when entering buffer
	-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
	auto_install = true,

	-- List of parsers to ignore installing (for "all")
	ignore_install = {},

	---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
	-- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

	highlight = {
		-- `false` will disable the whole extension
		enable = true,

		-- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
		-- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
		-- the name of the parser)
		-- list of language that will be disabled
		--disable = {},
		-- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
		disable = function(lang, buf)
			local max_filesize = 100 * 1024 -- 100 KB
			if lang == 'markdown' then
				max_filesize = 10000 * 1024 -- 10000 KB
			end
			local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,

		-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
		-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
		-- Using this option may slow down your editor, and you may see some duplicate highlights.
		-- Instead of true it can also be a list of languages
		additional_vim_regex_highlighting = false,
	},
	indent = { enable = true },
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<c-space>",
			node_incremental = "<c-space>",
			scope_incremental = "<a-enter>",
			node_decremental = "<a-backspace>",
		},
	},
	autotag = { enable = true },
})

-- use treesitter for folding
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"

-- nvim 0.12 breaking change: directive captures are now TSNode[] arrays but
-- nvim-treesitter expects a single TSNode. Apply after VimEnter so lazy.nvim
-- has finished loading nvim-treesitter (which would otherwise overwrite this).
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		local aliases = { ex = "elixir", pl = "perl", sh = "bash", uxn = "uxntal", ts = "typescript" }
		require("vim.treesitter.query").add_directive(
			"set-lang-from-info-string!",
			function(match, _, bufnr, pred, metadata)
				local node = match[pred[2]]
				if type(node) == "table" then node = node[1] end
				if not node then return end
				local alias = vim.treesitter.get_node_text(node, bufnr):lower()
				local lang = vim.filetype.match({ filename = "a." .. alias })
				metadata["injection.language"] = lang or aliases[alias] or alias
			end,
			{ force = true }
		)
	end,
})

