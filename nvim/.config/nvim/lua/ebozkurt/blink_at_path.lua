-- Provides @-triggered path completion for blink.cmp.
--
-- When typing "@" (not part of a word) in insert mode, offers file path
-- completions from the current buffer's cwd or git root. Paths are collected
-- via git ls-files when available (including untracked), otherwise via rg
-- --files. Results are cached per root, filtered to no-whitespace queries, and
-- returned as file completion items capped by max_entries.
local CompletionItemKind = require("blink.cmp.types").CompletionItemKind

local at_path = {}

local path_cache = {}

local function get_search_root(context, opts)
	local cwd = opts.get_cwd(context)
	local git_dir = vim.fs.find(".git", { upward = true, path = cwd })[1]
	if git_dir then
		return vim.fs.dirname(git_dir), true
	end
	return cwd, false
end

local function get_paths(root, is_git, opts, callback)
	local cache_key = root .. "::" .. (is_git and "git" or "rg")
	local cached = path_cache[cache_key]
	if cached and cached.paths then
		return callback(cached.paths)
	end

	if cached and cached.running then
		table.insert(cached.pending, callback)
		return
	end

	path_cache[cache_key] = { running = true, pending = { callback }, paths = nil }
	local cmd
	local split_delim = "\n"
	if is_git and vim.fn.executable("git") == 1 then
		split_delim = "\0"
		cmd = { "git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard", "-z" }
	else
		cmd = { "rg", "--files" }
		if opts.show_hidden_files_by_default then
			table.insert(cmd, "--hidden")
		end
	end
	vim.system(cmd, { cwd = root, text = true }, function(obj)
		local entry = path_cache[cache_key]
		entry.running = false
		if obj.code ~= 0 then
			entry.paths = {}
		else
			entry.paths = vim.split(obj.stdout or "", split_delim, { trimempty = true })
		end

		for _, cb in ipairs(entry.pending) do
			cb(entry.paths)
		end
		entry.pending = {}
	end)
end

local function empty_result(callback)
	callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
end

function at_path.new(opts)
	local self = setmetatable({}, { __index = at_path })
	self.opts = vim.tbl_deep_extend("keep", opts or {}, {
		get_cwd = function(context)
			return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
		end,
		show_hidden_files_by_default = false,
		max_entries = 10000,
	})
	return self
end

function at_path:get_trigger_characters()
	return { "@" }
end

function at_path:get_completions(context, callback)
	callback = vim.schedule_wrap(callback)

	if vim.api.nvim_get_mode().mode == "c" then
		return empty_result(callback)
	end

	local line_before_cursor = context.line:sub(1, context.cursor[2])
	local at_index = line_before_cursor:match(".*()@")
	if not at_index then
		return empty_result(callback)
	end

	if at_index > 1 then
		local prev_char = line_before_cursor:sub(at_index - 1, at_index - 1)
		if prev_char:match("[%w_]") then
			return empty_result(callback)
		end
	end

	local query = line_before_cursor:sub(at_index + 1)
	if query:find("%s") then
		return empty_result(callback)
	end

	if vim.fn.executable("rg") ~= 1 then
		return empty_result(callback)
	end

	local search_root, is_git = get_search_root(context, self.opts)
	local range = {
		start = { line = context.cursor[1] - 1, character = at_index - 1 },
		["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
	}

	get_paths(search_root, is_git, self.opts, function(paths)
		local items = {}
		for _, rel_path in ipairs(paths) do
			items[#items + 1] = {
				label = rel_path,
				filterText = "@" .. rel_path,
				kind = CompletionItemKind.File,
				insertText = rel_path,
				textEdit = { newText = rel_path, range = range },
				sortText = rel_path:lower(),
				data = { path = rel_path, full_path = search_root .. "/" .. rel_path, type = "file" },
			}
			if #items >= self.opts.max_entries then
				break
			end
		end

		callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
	end)
end

return at_path
