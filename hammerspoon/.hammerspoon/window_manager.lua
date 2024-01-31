local globals = require("globals")

hs.loadSpoon("ShiftIt")
spoon.ShiftIt:bindHotkeys({
  left = { globals.ctrl_alt, 'left' },
  right = { globals.ctrl_alt, 'right' },
  up = { globals.ctrl_alt, 'up' },
  down = { globals.ctrl_alt, 'down' },
  upleft = { globals.ctrl_alt, 'u' },
  upright = { globals.ctrl_alt, 'i' },
  botleft = { globals.ctrl_alt, 'j' },
  botright = { globals.ctrl_alt, 'k' },
  maximum = { globals.ctrl_alt, 'f' },
  -- these are disabled in the spoon as well
  -- toggleFullScreen = { globals.ctrl_alt, 'f' },
  -- toggleZoom = { globals.ctrl_alt, 'f' },
  center = { globals.ctrl_alt, 'c' },
  nextScreen = { globals.hyper, 'right' },
  previousScreen = { globals.hyper, 'left' },
  resizeOut = { globals.ctrl_alt, '=' },
  resizeIn = { globals.ctrl_alt, '-' }
})
spoon.ShiftIt:setWindowCyclingSizes({ 50, 33, 67 }, { 50 })

hs.hotkey.bind(globals.ctrl_alt, "c", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()

    local customWidthPercent = 0.8
    local customHeightPercent = 0.85
    f.w = max.w * customWidthPercent
    f.h = max.h * customHeightPercent
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 2
    win:setFrame(f, 0)
end)

-- screen related operations
local function getTargetScreen(currentScreen, direction)
  local allScreens = hs.screen.allScreens()
  local screenCount = #allScreens
  local currentIndex

  for i, screen in ipairs(allScreens) do
    if screen == currentScreen then
      currentIndex = i
      break
    end
  end

  if direction == "next" then
    return allScreens[(currentIndex % screenCount) + 1]
  elseif direction == "previous" then
    return allScreens[(currentIndex - 2) % screenCount + 1]
  end
end

local function moveToScreen(direction, keepRelativePosition)
  local currentScreen = hs.mouse.getCurrentScreen()
  local targetScreen = getTargetScreen(currentScreen, direction)

  if targetScreen then
    local targetScreenFrame = targetScreen:fullFrame()
    local newPosX, newPosY

    if keepRelativePosition then
      -- Calculate relative position if keepRelativePosition is true
      local currentScreenFrame = currentScreen:fullFrame()
      local mousePos = hs.mouse.absolutePosition()

      local relativeX = (mousePos.x - currentScreenFrame.x) / currentScreenFrame.w
      local relativeY = (mousePos.y - currentScreenFrame.y) / currentScreenFrame.h

      newPosX = targetScreenFrame.x + targetScreenFrame.w * relativeX
      newPosY = targetScreenFrame.y + targetScreenFrame.h * relativeY
    else
      -- Center the mouse if keepRelativePosition is false
      newPosX = targetScreenFrame.x + targetScreenFrame.w / 2
      newPosY = targetScreenFrame.y + targetScreenFrame.h / 2
    end

    -- Move the mouse to the new position
    hs.mouse.absolutePosition(hs.geometry.point(newPosX, newPosY))
  end
end


hs.hotkey.bind(globals.hyper, "m", function()
  moveToScreen("next", true)
end)
hs.hotkey.bind({'shift', 'alt'}, "m", function()
  moveToScreen("next", false)
end)
hs.hotkey.bind(globals.hyper, "n", function()
  moveToScreen("previous", true)
end)
hs.hotkey.bind({'shift', 'alt'}, "n", function()
  moveToScreen("previous", false)
end)


-- hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "i", function()
--   hs.spaces.addSpaceToScreen()
-- end)

