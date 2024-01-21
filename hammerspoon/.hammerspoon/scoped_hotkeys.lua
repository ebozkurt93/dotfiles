local helpers = require("helpers")

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
      autoWithdraw = true,
      withdrawAfter = 5,
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

-- todo: update this to be more useable, I probably need two shortcuts(One for desktop and one for downloads)
helpers.hotkeyExcludingApp({ "alt", "shift" }, "d", "Google Chrome", function()
  hs.execute("open ~/Desktop")
end)

local _ = helpers.keystrokesScopedToApp("bb ", "Google Chrome", function()
  local urlStartsWith = "https://www.reddit.com/"

  if not helpers.isCurrentTabUrlStartingWith(urlStartsWith) then
    return
  end

  local jsCommand = [[

// toggle reddit theme
document.getElementById('USER_DROPDOWN_ID').click();
[...document.querySelectorAll("span")].filter(s => s.textContent === 'Dark Mode')[0].click()
//document.getElementsByClassName('icon icon-night')[0].click();

]]

  helpers.runJsOnCurrentBrowserTab(jsCommand)
  hs.eventtap.keyStroke({}, "escape", 0)
end)
