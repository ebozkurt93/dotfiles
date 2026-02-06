-- Simple function call tracer / monkey-patcher
--
-- Purpose:
--   Temporarily wrap any function to capture a Lua stack trace
--   when it is called, helping identify *who* is calling it at runtime.
--
-- Typical use cases:
--   - Tracking deprecated API usage (e.g. vim.tbl_flatten)
--   - Finding which plugin triggers a function
--   - Debugging early / implicit calls during startup
--
-- IMPORTANT:
--   This must run BEFORE the target function is first called.
--   Ideally place usage at the very top of init.lua, before plugin managers.

local M = {}

-- Default output path for traces.
-- Uses Neovim's cache dir and sanitizes the function name.
local function default_path(name)
  local safe = name:gsub("[^%w%._-]", "_")
  return vim.fn.stdpath("cache") .. "/trace_" .. safe .. ".txt"
end

-- Delete trace files created by this module.
--
-- @param pattern? string
--   Glob pattern relative to stdpath("cache").
--   Defaults to "trace_*.txt".
--
-- @return integer
--   Number of files deleted.
function M.clear(pattern)
  pattern = pattern or "trace_*.txt"
  local dir = vim.fn.stdpath("cache")
  local files = vim.fn.globpath(dir, pattern, false, true)

  local deleted = 0
  for _, f in ipairs(files) do
    if vim.fn.delete(f) == 0 then
      deleted = deleted + 1
    end
  end

  return deleted
end

-- Wrap a function to record a stack trace when it is called.
--
-- @param tbl  table   Table containing the function (e.g. vim, vim.lsp)
-- @param key  string  Function name on the table
-- @param opts table?  Optional behavior configuration
--   opts.once   boolean  (default: true)
--     If true, only capture the first call.
--
--   opts.error  boolean
--     If true, throw an error after capturing the trace
--     (useful for guaranteed visibility).
--
--   opts.file   string
--     Custom output file path for the trace.
--
--   opts.notify boolean (default: true)
--     Show a notification pointing to the trace file.
--
--   opts.header string
--     Custom header line for the stack trace.
--
-- @return function
--   A restore function that resets tbl[key] to the original implementation.
function M.wrap(tbl, key, opts)
  opts = opts or {}

  local orig = tbl[key]
  if type(orig) ~= "function" then
    error(("trace.wrap: %s is not a function"):format(key))
  end

  local once = opts.once ~= false
  local fired = false
  local file = opts.file or default_path(key)

  tbl[key] = function(...)
    if (not once) or (not fired) then
      fired = true

      local header = opts.header or (key .. " called")
      local tb = debug.traceback(header, 2)

      vim.fn.writefile(vim.split(tb, "\n"), file)

      if opts.notify ~= false then
        vim.schedule(function()
          vim.notify("Wrote trace to:\n" .. file)
        end)
      end

      if opts.error then
        error(tb)
      end
    end

    return orig(...)
  end

  -- Restore helper
  return function()
    tbl[key] = orig
  end
end

return M

-- Example usage:
--   local trace = require("ebozkurt.debug.trace")
--   trace.wrap(vim, "tbl_flatten", { once = true })
--   -- clear all traces:
--   --   :lua print(trace.clear())
--   -- clear only one function's trace:
--   --   :lua print(trace.clear("trace_tbl_flatten.txt"))
