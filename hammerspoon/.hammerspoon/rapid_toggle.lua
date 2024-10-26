local macos_helpers = require("macos_helpers")

local conditionalBindings = {}

local function enableKeybindings()
  for _, binding in ipairs(conditionalBindings) do
    binding:enable()
  end
end

local function disableKeybindings()
  for _, binding in ipairs(conditionalBindings) do
    binding:disable()
  end
end

local disableTimer = hs.timer.delayed.new(5, disableKeybindings)

hs.hotkey.bind({ "ctrl" }, "`", function()
  enableKeybindings()
  disableTimer:start()
end)

local function disableAfter(func)
  return function()
    func()
    disableKeybindings()
    disableTimer:stop()
  end
end

conditionalBindings = {
  hs.hotkey.new({}, "escape", disableKeybindings),
  hs.hotkey.new({}, "b", disableAfter(macos_helpers.toggleBluetooth)),
  hs.hotkey.new({}, "d", disableAfter(macos_helpers.dockMovePosition)),
  hs.hotkey.new({}, "g", disableAfter(macos_helpers.toggleGrayscale)),
  hs.hotkey.new({}, "n", disableAfter(macos_helpers.clearNotifications)),
  hs.hotkey.new({}, "p", disableAfter(macos_helpers.toggleLowPowerMode)),
  hs.hotkey.new({}, "r", disableAfter(macos_helpers.dockClearRecentApps)),
  hs.hotkey.new({}, "s", disableAfter(macos_helpers.toggleBrightness)),
  hs.hotkey.new({}, "t", disableAfter(macos_helpers.toggleTheme)),
  hs.hotkey.new({}, "w", disableAfter(macos_helpers.setWallpaper)),
  hs.hotkey.new({}, "i", disableAfter(macos_helpers.toggleWifi))
}

disableKeybindings()

return { conditionalBindings, disableTimer }
