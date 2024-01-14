local globals = require("globals")

hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")

hs.alert.show("Config loaded")
