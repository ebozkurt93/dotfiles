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

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "escape",
    disableKeybindings
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "b",
    disableAfter(function()
      macos_helpers.toggleBluetooth()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "d",
    disableAfter(function()
      macos_helpers.dockMovePosition()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "g",
    disableAfter(function()
      macos_helpers.toggleGrayscale()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "n",
    disableAfter(function()
      macos_helpers.clearNotifications()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "p",
    disableAfter(function()
      hs.execute(
        [[
~/bin/helpers/low-power-mode-toggle.sh
]],
        true
      )
      macos_helpers.refreshBitBarPlugins()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "r",
    disableAfter(function()
      macos_helpers.dockClearRecentApps()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "s",
    disableAfter(function()
      macos_helpers.toggleBrightness()
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "t",
    disableAfter(function()
      hs.execute([[
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'
]])
    end)
  )
)

table.insert(
  conditionalBindings,
  hs.hotkey.new(
    {},
    "w",
    disableAfter(function()
      hs.execute([[
~/bin/helpers/set_wallpaper.sh
]])
    end)
  )
)

disableKeybindings()

return { conditionalBindings, disableTimer }
