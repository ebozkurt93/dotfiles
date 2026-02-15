local M = {}

-- Macros: ONE string each. No ranges.
-- If you want Ex, include ":" and end with "<CR>".
-- Only "desc" is shown/used for selection.
M.macros = {
  {
    desc = "Add trailing comma",
    keys = [[:s/\s*,\?\s*$/,/<CR>]],
  },
  {
    desc = "Wrap line in single quotes + trailing comma",
    keys = [[:s/^\s*\(.*\)\s*$/'\1',/<CR>]],
  },
  {
    desc = "Remove trailing comma",
    keys = [[:s/,\s*$//<CR>]],
  },
  {
    desc = "Join selected lines into one (single spaces)",
    keys = [[J0]],
  },
  -- {
  --   desc = "Duplicate current line below",
  --   keys = [[yyp]],
  -- },
}

local function tc(s)
  return vim.api.nvim_replace_termcodes(s, true, false, true)
end

local function preview_keys(keys)
  return (keys or ""):gsub("\n", "\\n"):gsub("%s+", " ")
end

local function restore_visual(line1, line2)
  vim.fn.setpos("'<", { 0, line1, 1, 0 })
  vim.fn.setpos("'>", { 0, line2, 1, 0 })
  vim.cmd("normal! gv")
end

local function save_search()
  return vim.fn.getreg("/")
end

local function restore_search(val)
  vim.fn.setreg("/", val or "")
end

local function hard_normal_and_flush()
  vim.api.nvim_feedkeys(tc("<C-\\><C-n>"), "nx", false)
  vim.api.nvim_feedkeys(tc("<Esc>"), "nx", false)
  vim.api.nvim_feedkeys(tc("<Ignore>"), "nx", false)
end

local function warn(msg)
  vim.notify(msg, vim.log.levels.WARN, { title = "MacroPicker" })
end

-- add the 'e' flag to :s/// so "pattern not found" won't error (E486)
local function add_sub_e_flag(ex)
  -- matches only substitute commands
  if not ex:match("^%s*s%W") then return ex end

  -- already has e flag?
  local last = ex:match("([^\\])$") -- cheap-ish; still ok for typical :s usage
  if ex:match("[gIc%l]*e[glIc%l]*%s*$") then
    return ex
  end

  -- append e to flags area if present; otherwise add /e
  -- handle common :s/pat/repl/flags form
  local a, b, c, flags = ex:match("^%s*(s)(%W.-%W)(.-)(%W[%w]*)%s*$")
  if a and b and c and flags then
    if flags == "/" then
      return "s" .. b .. c .. "/e"
    end
    -- flags like "/g", "/I", etc.
    return "s" .. b .. c .. flags .. "e"
  end

  -- fallback: just add e at end (works for standard :s/// forms)
  return ex .. "e"
end

local function exec_ex_on_line(lnum, ex)
  ex = add_sub_e_flag(ex)
  local ok, err = pcall(vim.cmd, ("silent %d%s"):format(lnum, ex))
  if not ok then
    warn(("Macro failed on line %d: %s"):format(lnum, tostring(err)))
  end
end

local function exec_normal_on_line(keys, lnum)
  local ok, err = pcall(vim.cmd, "keepjumps normal! " .. (keys or ""))
  if not ok then
    warn(("Macro failed on line %d: %s"):format(lnum, tostring(err)))
  end
end

-- Execute ONE macro on ONE line.
-- If macro is exactly ":...<CR>" treat it as Ex on that line.
-- Otherwise treat as normal-mode keys via :normal! (no remap, no typeahead).
local function exec_one_on_line(keys, lnum)
  keys = keys or ""

  hard_normal_and_flush()
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })

  local ex = keys:match("^%s*:(.-)<CR>%s*$")
  if ex then
    exec_ex_on_line(lnum, ex)
    return
  end

  exec_normal_on_line(keys, lnum)
end

-- Run once per selected line (bottom->top to avoid duplication issues).
local function run_macro_per_line(keys, line1, line2, has_range)
  local saved_search = save_search()

  if has_range then
    for l = line2, line1, -1 do
      exec_one_on_line(keys, l)
    end
    restore_search(saved_search)
    restore_visual(line1, line2)
  else
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    exec_one_on_line(keys, cur)
    restore_search(saved_search)
  end
end

local function copy_macro(keys, reg)
  reg = (reg and reg ~= "") and reg or "q"
  -- Turn "<CR>", "<Esc>", etc. into real keycodes so @q works
  vim.fn.setreg(reg, tc(keys or ""), "v")
end


local function picker(opts)
  opts = opts or {}
  local default_reg = opts.default_reg or "q"
  local line1, line2 = opts.line1, opts.line2
  local has_range = opts.has_range

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 44 },
      { remaining = true },
    },
  })

  local function make_display(m)
    local k = preview_keys(m.keys)
    if #k > 80 then k = k:sub(1, 77) .. "…" end
    return displayer({ m.desc or "", k })
  end

  pickers.new(opts, {
    prompt_title = "MacroPicker (Enter=run  C-y=copy→q  C-q=copy→reg)",
    finder = finders.new_table({
      results = M.macros,
      entry_maker = function(m)
        return {
          value = m,
          ordinal = table.concat({ m.desc or "", m.keys or "" }, " "),
          display = function() return make_display(m) end,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local function sel()
        local e = action_state.get_selected_entry()
        return e and e.value or nil
      end

      local function after_close(fn)
        actions.close(prompt_bufnr)
        vim.schedule(function()
          hard_normal_and_flush()
          fn()
        end)
      end

      local function do_run()
        local m = sel()
        if not m then return end
        after_close(function()
          run_macro_per_line(m.keys, line1, line2, has_range)
        end)
      end

      local function do_copy(reg)
        local m = sel()
        if not m then return end
        after_close(function()
          copy_macro(m.keys, reg or default_reg)
        end)
      end

      actions.select_default:replace(do_run)

      map({ "i", "n" }, "<C-y>", function() do_copy(default_reg) end)
      map({ "i", "n" }, "<C-q>", function()
        vim.ui.input({ prompt = "Register: ", default = default_reg }, function(reg)
          if reg and reg ~= "" then do_copy(reg) end
        end)
      end)

      return true
    end,
  }):find()
end

function M.setup(opts)
  opts = opts or {}
  local default_reg = opts.default_reg or "q"

  vim.api.nvim_create_user_command("MacroPicker", function(cmdopts)
    picker({
      default_reg = default_reg,
      line1 = cmdopts.line1,
      line2 = cmdopts.line2,
      has_range = (cmdopts.range or 0) > 0,
    })
  end, { range = true })
end

return M
