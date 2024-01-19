local globals = require("globals")
local helpers = require("helpers")

-- hs.loadSpoon("EmmyLua") -- enable when want to regenerate lua annotations for lsp
hs.hotkey.bind(globals.hyper, "d", hs.toggleConsole)

helpers.hotkeyScopedToApp({ "cmd" }, "r", "Spotify", function()
  local app = hs.application.frontmostApplication()
  if app then
    app:kill()
    hs.timer.doAfter(1, function()
      hs.application.launchOrFocus("Spotify")
    end)
  end
end)

helpers.hotkeyScopedToApp({ "cmd" }, "r", "Obsidian", function(app)
  app:selectMenuItem({ "View", "Force Reload" })
end)

helpers.hotkeyScopedToApp({ "cmd" }, "m", "Obsidian", function(app)
  app:selectMenuItem({ "Window", "Minimize" })
end)

helpers.hotkeyScopedToApp({ "cmd" }, "f", "Pocket Casts", function(app)
  if helpers.isCurrentWindowInFullScreen() then
    app:selectMenuItem({ "Window", "Exit Full Screen" })
  else
    app:selectMenuItem({ "Window", "Enter Full Screen" })
  end
end)

helpers.hotkeyScopedToApp({ "cmd", "alt" }, "f", "VLC", function(app)
  app:selectMenuItem({ "Video", "Float on Top" })
end)

helpers.hotkeyScopedToApp({ "cmd" }, "a", "MultiViewer for F1", function(app)
  app:selectMenuItem({ "Window", "Bring All to Front" })
end)

-- Google Chrome
helpers.hotkeyScopedToApp({ "cmd", "shift" }, "0", "Google Chrome", function(app)
  app:selectMenuItem({ "Profiles", "Erdem" })
end)

-- todo: move this to work part
helpers.hotkeyScopedToApp({ "cmd", "shift" }, "9", "Google Chrome", function(app)
  app:selectMenuItem({ "Profiles", "Bemlo" })
end)

helpers.hotkeyScopedToApp({ "cmd", "shift" }, "8", "Google Chrome", function(app)
  app:selectMenuItem({ "Profiles", "VPN" })
end)

helpers.hotkeyScopedToApp({ "ctrl" }, "d", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab", "Duplicate tab" })
end)

helpers.hotkeyScopedToApp({ "alt" }, "d", "Google Chrome", function()
  hs.eventtap.keyStroke({ "cmd" }, "l", 0)
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  hs.eventtap.keyStroke({}, "escape", 0)
  hs.eventtap.keyStroke({ "cmd", "shift" }, "n", 0)
  hs.eventtap.keyStroke({ "cmd" }, "l", 0)
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  hs.eventtap.keyStroke({}, "return", 0)
end)

helpers.hotkeyScopedToApp({ "cmd" }, "g", "Google Chrome", function()
  hs.eventtap.rightClick(hs.mouse.absolutePosition())
  hs.eventtap.keyStroke({}, "g", 0)
  hs.eventtap.keyStroke({}, "return", 0)
end)

helpers.hotkeyScopedToApp({ "ctrl" }, "m", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab", "Mute site" })
  local title = hs.window.focusedWindow():title()
  hs.notify
    .new({
      title = "Chrome Mute Toggle",
      informativeText = "Muting -" .. title,
      autoWithdraw = true, -- Automatically dismiss the notification after a few seconds
      withdrawAfter = 5, -- Duration in seconds before auto-dismissing
    })
    :send()
end)

helpers.hotkeyScopedToApp({ "cmd", "alt" }, "t", "Google Chrome", function()
  hs.eventtap.rightClick(hs.mouse.absolutePosition())
  hs.eventtap.keyStroke({}, "t", 0)
  hs.eventtap.keyStroke({}, "return", 0)
end)

helpers.hotkeyScopedToApp({ "cmd", "ctrl" }, "t", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab", "New Tab to the Right" })
end)

helpers.hotkeyScopedToApp({ "cmd", "ctrl" }, "p", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab", "Pin tab" })
end)

helpers.hotkeyScopedToApp({ "ctrl", "alt" }, "m", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab" })
end)

helpers.hotkeyExcludingApp({ "alt", "shift" }, "d", "Google Chrome", function()
  hs.execute("open ~/Downloads")
end)

local _ = helpers.keystrokesScopedToApp("bb ", "Google Chrome", function()
  -- todo: refactor this and extract to a function
  local _, url =
    hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')

  local start = "https://www.reddit.com/"
  if url:sub(1, #start) ~= start then
    return
  end

  local script = [[
var chrome = Application("Google Chrome");

var command = `
    (function() {

// toggle reddit theme
document.getElementById('USER_DROPDOWN_ID').click();
[...document.querySelectorAll("span")].filter(s => s.textContent === 'Dark Mode')[0].click()
//document.getElementsByClassName('icon icon-night')[0].click();
    })();

`
chrome.windows[0].activeTab.execute({javascript:command})
  ]]
  hs.osascript.javascript(script:format("Google Chrome"))

  hs.eventtap.keyStroke({}, "escape", 0)
end)

require("reload")
require("window_manager")
require("fuzzy_window_switcher")
require("text_expander")
local _ = require("mouse_snap_window")
-- temporarily disabled
-- require("google_meet_mic_toggle")

hs.alert.show("Config loaded")
