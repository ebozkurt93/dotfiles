local notes_dir = os.getenv("HOME") .. "/Documents/EB-Notes-Main"

local function directory_exists(path)
  local stat = vim.loop.fs_stat(path)
  return (stat and stat.type == "directory") or false
end

if not directory_exists(notes_dir) then
	vim.notify("Obsidian notes directory is missing", vim.log.levels.WARN)
	return
end

require("obsidian").setup({
	dir = notes_dir,
	completion = {
		nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
	},
	ui = { enable = false },
	disable_frontmatter = true,
})
