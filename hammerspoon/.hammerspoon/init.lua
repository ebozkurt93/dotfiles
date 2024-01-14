local globals = require("globals")

hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")
require("fuzzy_window_switcher")

hs.alert.show("Config loaded")
