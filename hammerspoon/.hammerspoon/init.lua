local globals = require("globals")
local helpers = require("helpers")

-- hs.loadSpoon("EmmyLua") -- enable when want to regenerate lua annotations for lsp
hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")
require("fuzzy_window_switcher")
require("text_expander")
local _ = require("mouse_snap_window")
local _ = require("scoped_hotkeys")
local _ = require("spotify")
helpers.loadModuleIfAvailable('personal')

-- temporarily disabled
-- require("google_meet_mic_toggle")

hs.alert.show("Config loaded")
