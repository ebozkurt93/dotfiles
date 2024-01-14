local globals = require("globals")

-- hs.loadSpoon("EmmyLua") -- enable when want to regenerate lua annotations for lsp
hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")
require("fuzzy_window_switcher")
-- temporarily disabled
-- require("google_meet_mic_toggle")

hs.alert.show("Config loaded")
