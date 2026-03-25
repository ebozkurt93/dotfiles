local macos_helpers = require("macos_helpers")

local watcher = hs.distributednotifications.new(function()
  macos_helpers.syncClaudeTheme()
end, "AppleInterfaceThemeChangedNotification")

watcher:start()
macos_helpers.syncClaudeTheme()

return watcher
