local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

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
  {
    ["text"] = "Connect To Trackpad",
    ["action"] = function()
      os.execute("~/bin/btt &")
    end,
  },
  {
    ["text"] = "Restart Bartender 5",
    ["action"] = function()
      hs.execute("killall 'Bartender 5'; sleep 1; open -gj -a '/Applications/Bartender 5.app'")
    end,
  },
  {
    ["text"] = "Restart BitBar",
    ["action"] = function()
      macos_helpers.restartBitBar()
    end,
  },
  {
    ["text"] = "Toggle Grayscale",
    ["action"] = function()
      macos_helpers.toggleGrayscale()
    end,
  },
}

local personalMenuItems = {}
if helpers.isModuleAvailable("personal") then
  personalMenuItems = require("personal").actionMenuItems
end

originalMenuItems = helpers.mergeTables(originalMenuItems, personalMenuItems)

local menuItems = helpers.removeKeyFromTableArray(originalMenuItems, "action")

-- Function to show the menu
local function showMenu()
  local chooser = hs.chooser.new(function(choice)
    if not choice then
      return
    end
    helpers.findTableArrayItemByField(originalMenuItems, "text", choice.text).action()
  end)

  chooser:choices(menuItems)
  chooser:show()
end

hs.hotkey.bind({ "ctrl", "shift" }, "z", showMenu)

return { menuItems }
