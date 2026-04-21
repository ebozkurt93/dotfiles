local macos_helpers = require("macos_helpers")

local watcher = hs.distributednotifications.new(function()
  macos_helpers.updateDarkModeCache()
end, "AppleInterfaceThemeChangedNotification")

watcher:start()
macos_helpers.updateDarkModeCache()

return watcher
