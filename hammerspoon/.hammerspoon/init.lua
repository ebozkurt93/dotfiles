local globals = require("globals")
local helpers = require("helpers")

hs.timer.doAfter(0, function()
  -- regenerates lua annotations for lsp
  hs.loadSpoon("EmmyLua")
end)

hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")
require("menubar_colors")
local _ = require("fuzzy_window_switcher")
local _ = require("chrome_tab_switcher")
local _ = require("text_expander")
local _ = require("mouse_snap_window")
local _ = require("mouse_position_indicator")
local _ = require("scoped_hotkeys")
local _ = require("spotify")
local _ = require("rapid_toggle")
local _ = require("action_menu")
-- local _ = require("caffeinate")
local _, _ = helpers.safeRequire("personal", {}, nil)

-- temporarily disabled
-- require("google_meet_mic_toggle")

hs.alert.show("Config loaded")

