require("obsidian").setup({
	dir = "~/Documents/EB-Notes-Main",
	completion = {
		nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
	},
	ui = { enable = false },
	disable_frontmatter = true,
})
