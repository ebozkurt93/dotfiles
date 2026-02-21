local notes_dir = os.getenv("HOME") .. "/Documents/EB-Notes-Main"

require("obsidian").setup({
	dir = notes_dir,
	workspaces = {
      {
        name = "personal",
        path = notes_dir,
      },
    },
	completion = {
		nvim_cmp = true,
	},
	ui = { enable = false },
	disable_frontmatter = true,
})
