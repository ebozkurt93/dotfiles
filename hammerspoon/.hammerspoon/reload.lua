local globals = require("globals")

hs.hotkey.bind(globals.hyper, "r", function()
  hs.reload()
end)
