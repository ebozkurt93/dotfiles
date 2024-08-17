local notes_dir = os.getenv("HOME") .. "/Documents/EB-Notes-Main"

local function directory_exists(path)
	local stat = vim.loop.fs_stat(path)
	return (stat and stat.type == "directory") or false
end

if not directory_exists(notes_dir) then
	local helpers = require('ebozkurt.helpers')
	local path = vim.fn.stdpath('data') .. '/obsidian_notes_dir_info.json'
	local t = helpers.read_json_to_table(path)

	local last_notified = t and t.last_notified or 0
	local notify_interval = 24 * 60 * 60 -- 24 hours

	local current_time = os.time()

	if current_time >= last_notified + notify_interval then
		vim.notify("Obsidian notes directory is missing", vim.log.levels.WARN)
		t = {
			last_notified = current_time,
			missing_notes_dir = notes_dir,
		}
		helpers.save_table_to_json(t, path)
	end

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
