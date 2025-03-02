local uv = vim.loop
local has_telescope_core, telescope = pcall(require, "telescope")
local has_luasnip, luasnip = pcall(require, "luasnip")

if has_telescope_core then
  telescope = require("telescope")
else
  telescope = nil
end

-- Ensure Lua can find the snippets folder
local snippets_path = vim.fn.stdpath("config") .. "/snippets/"
package.path = snippets_path .. "?.lua;" .. package.path

-- Load all Lua snippet files in a directory and its subdirectories
local function load_snippets_from_dir(dir)
  local snippets = {}

  -- Helper function for recursive scanning
  local function scan_folder(path)
    local handle = uv.fs_scandir(path)
    if not handle then
      return
    end

    while true do
      local name, file_type = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      local full_path = path .. "/" .. name

      if file_type == "directory" then
        -- Recursively scan subdirectories
        scan_folder(full_path)
      elseif file_type == "file" and name:match("%.lua$") then
        -- Convert file path to a Lua module name
        local module_name = full_path:gsub("%.lua$", ""):gsub("^" .. snippets_path, ""):gsub("/", "."):gsub("^%.", "")

        -- Unload cached module to force reloading
        package.loaded[module_name] = nil

        -- Load the snippet file
        local success, snippet_list = pcall(require, module_name)
        if success and type(snippet_list) == "table" then
          for _, snippet in ipairs(snippet_list) do
            table.insert(snippets, snippet)
          end
        else
          print("Failed to load snippets from: " .. full_path)
        end
      end
    end
  end

  -- Start scanning from the root directory
  scan_folder(dir)
  table.sort(snippets, function(a, b)
    return a.name < b.name
  end)

  return snippets
end

local dynamic_defaults = {
  T_DATE = function()
    return os.date("%Y-%m-%d")
  end,
}

-- Expand snippet using LuaSnip
local function expand_snippet(query)
  if has_luasnip then
    -- Prevent LuaSnip from interpreting `$` as a special character
    local processed_query = query:gsub("($)(%a+)", "\\%1%2") -- Escapes $ so LuaSnip ignores it

    -- Only replace `${1:T_DATE}` placeholders, ignore $ symbols
    processed_query = processed_query:gsub("%${(%d+):([^}]+)}", function(index, placeholder)
      local replacement = dynamic_defaults[placeholder] and dynamic_defaults[placeholder]() or placeholder
      return string.format("${%s:%s}", index, replacement)
    end)

    -- Expand the snippet in LuaSnip
    luasnip.snip_expand(luasnip.parser.parse_snippet("snippet", processed_query))
  end
end

-- Use Telescope for fuzzy snippet selection
local function select_snippet_telescope(snippets)
  if not has_telescope_core then
    print("Telescope.nvim not found!")
    return
  elseif not has_luasnip then
    print("Luasnip not found!")
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local picker_entries = {}
  for _, snippet in ipairs(snippets) do
    local tag_str = snippet.tags and (" [" .. table.concat(snippet.tags, ", ") .. "]") or ""
    table.insert(picker_entries, {
      value = snippet,
      display = snippet.name .. tag_str .. " - " .. (snippet.description or ""),
      ordinal = snippet.name .. " " .. (snippet.description or "") .. " " .. tag_str .. " " .. snippet.query,
    })
  end

  pickers
      .new({}, {
        prompt_title = "Snippets",
        finder = finders.new_table({
          results = picker_entries,
          entry_maker = function(entry)
            return {
              value = entry.value,
              display = entry.display,
              ordinal = entry.ordinal,
            }
          end,
        }),
        sorter = sorters.get_generic_fuzzy_sorter({}),
        previewer = previewers.new_buffer_previewer({
          define_preview = function(self, entry, status)
            local filetype = entry.value.filetype or "" -- Use defined filetype, else none
            if filetype ~= "" then
              vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", filetype)
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(entry.value.query, "\n"))
          end,
        }),
        attach_mappings = function(_, map)
          map("i", "<CR>", function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            if entry then
              local query = entry.value.query

              -- Trim leading and trailing newlines
              local lines = vim.split(query, "\n")

              -- Remove empty lines from the start
              while #lines > 0 and lines[1]:match("^%s*$") do
                table.remove(lines, 1)
              end

              -- Remove empty lines from the end
              while #lines > 0 and lines[#lines]:match("^%s*$") do
                table.remove(lines, #lines)
              end

              -- Join trimmed query back into a string
              query = table.concat(lines, "\n")

              -- Expand with LuaSnip, keeping placeholders intact
              expand_snippet(query)
            end
          end)
          return true
        end,
      })
      :find()
end

-- Command to search and paste a snippet using Telescope
vim.api.nvim_create_user_command("Snippets", function()
  select_snippet_telescope(load_snippets_from_dir(snippets_path))
end, {})
