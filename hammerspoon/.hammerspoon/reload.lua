local globals = require("globals")

-- hs.reload() re-executes init.lua in a fresh Lua state but never fires
-- hs.shutdownCallback (only quitting the app does), so native NSStatusItems
-- that helpers.registerMenubar tracked for cleanup (e.g. github_prs.lua's
-- menu bar item) are orphaned rather than deleted, leaving a stale zombie
-- icon frozen at whatever it last showed. Run that cleanup manually first.
hs.hotkey.bind(globals.hyper, "r", function()
  if hs.shutdownCallback then hs.shutdownCallback() end
  hs.reload()
end)
