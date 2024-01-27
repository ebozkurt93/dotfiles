local globals = require("globals")
local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

hs.timer.doAfter(0, function()
  -- regenerates lua annotations for lsp
  hs.loadSpoon("EmmyLua")
end)

hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

require("reload")
require("window_manager")
require("menubar_colors")
local _ = require("fuzzy_window_switcher")
local _ = require("text_expander")
local _ = require("mouse_snap_window")
local _ = require("scoped_hotkeys")
local _ = require("spotify")
local _ = require("rapid_toggle")
local _ = helpers.loadModuleIfAvailable("personal")

-- temporarily disabled
-- require("google_meet_mic_toggle")

hs.alert.show("Config loaded")

local function removeKeyFromTableArray(tableArray, keyToRemove)
  local newArray = {}
  for _, item in ipairs(tableArray) do
    local newItem = {}
    for key, value in pairs(item) do
      if key ~= keyToRemove then
        newItem[key] = value
      end
    end
    table.insert(newArray, newItem)
  end
  return newArray
end

local function findRowById(tableArray, text)
  for _, row in ipairs(tableArray) do
    if row.text == text then
      return row
    end
  end
  return nil
end

local originalMenuItems = {
  {
    ["text"] = "Toggle Display Mirroring",
    ["action"] = function()
      hs.execute("~/bin/mirror")
      macos_helpers.toggleBrightness()
    end,
  },
  {
    ["text"] = "Toggle Mirrored Displays",
    ["action"] = function()
      hs.execute("~/bin/mirror -l 1 0")
    end,
  },
}

local menuItems = removeKeyFromTableArray(originalMenuItems, "action")

-- Function to show the menu
local function showMenu()
  local chooser = hs.chooser.new(function(choice)
    if not choice then
      return
    end
    findRowById(originalMenuItems, choice.text).action()
  end)

  chooser:choices(menuItems)
  chooser:show()
end

hs.hotkey.bind({ "ctrl", "shift" }, "z", showMenu)
