require("nvim-treesitter").setup()

require("nvim-treesitter").install({
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
})

-- Disable treesitter highlighting for large files
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		local max_filesize = 100 * 1024 -- 100 KB
		if vim.bo[args.buf].filetype == "markdown" then
			max_filesize = 10000 * 1024 -- 10000 KB
		end
		local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
		if ok and stats and stats.size > max_filesize then
			vim.treesitter.stop(args.buf)
		end
	end,
})

-- use treesitter for folding
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
