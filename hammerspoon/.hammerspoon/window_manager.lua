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

    local customWidthPercent = 0.60
    local customHeightPercent = 0.60
    f.w = max.w * customWidthPercent
    f.h = max.h * customHeightPercent
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 2
    win:setFrame(f, 0)
end)
