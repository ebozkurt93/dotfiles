local globals = require("globals")
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

helpers.hotkeyScopedToApp({ "cmd", "ctrl"}, "f", "FreeCAD", function(app)
    app:selectMenuItem({ "View", "Fullscreen" })
end)

helpers.hotkeyScopedToApp({ "cmd", "alt" }, "f", "VLC", function(app)
  app:selectMenuItem({ "Video", "Float on Top" })
end)

helpers.hotkeyScopedToApp({ "cmd" }, "a", "MultiViewer for F1", function(app)
  app:selectMenuItem({ "Window", "Bring All to Front" })
end)

helpers.hotkeyScopedToApp({ "cmd", "alt" }, "r", "Ghostty", function(app)
  local appName = app:name()
  app:kill()
  hs.timer.doAfter(0.25, function()
    hs.application.launchOrFocus(appName)
  end)
end)


-- Google Chrome
hs.hotkey.bind({ "cmd", "shift" }, "0", function()
  local app = hs.application.get("Google Chrome")
  app:selectMenuItem({ "Profiles", "Erdem" })
end)

hs.hotkey.bind({ "cmd", "shift" }, "8", function()
  local app = hs.application.get("Google Chrome")
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

helpers.hotkeyScopedToApp({ "ctrl" }, "m", "Google Chrome", function(app)
  app:selectMenuItem({ "Tab", "Mute site" })
  local title = hs.window.focusedWindow():title()
  hs.notify
      .new({
        title = "Chrome Mute Toggle",
        informativeText = "Muting - " .. title,
        autoWithdraw = true,
        withdrawAfter = 2,
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

helpers.hotkeyScopedToApp({ "cmd", "ctrl" }, "f", "Google Chrome", function(app)
  app:selectMenuItem('(Enter|Exit) Full Screen', true)
end)

-- move tab to left/right
helpers.hotkeyScopedToApp({ "shift", "alt" }, "h", "Google Chrome", function()
  hs.eventtap.keyStroke({ 'ctrl', 'shift' }, 'pageup', 0)
end)

helpers.hotkeyScopedToApp({ "shift", "alt" }, "l", "Google Chrome", function()
  hs.eventtap.keyStroke({ 'ctrl', 'shift' }, 'pagedown', 0)
end)

local reddit = helpers.keystrokesScopedToApp("bb ", "Google Chrome", function()
  local urlStartsWith = "https://www.reddit.com/"

  if not helpers.isCurrentTabUrlStartingWith(urlStartsWith) then
    return
  end

  local jsCommand = [[

document.querySelectorAll('faceplate-dropdown-menu')[0].childNodes[0].click();
[...document.querySelectorAll('span')].filter(s => s.textContent === 'Dark Mode')[0].click();

setTimeout(function() {
document.querySelectorAll('faceplate-dropdown-menu')[0].childNodes[0].click();
document.activeElement.blur();
}, 250)

]]

  helpers.runJsOnCurrentBrowserTab(jsCommand)
  hs.timer.doAfter(0.1, function()
    hs.eventtap.keyStroke({ 'shift' }, "space")
  end)
end)

local kasmMuteToggle = helpers.hotkeyScopedToApp({ "shift", "alt" }, "m", "Google Chrome", function()
  if not helpers.isCurrentTabUrlStartingWith("http://home:3001") and
      not helpers.isCurrentTabUrlStartingWith("https://u.local.erdem-bozkurt.com")
  then
    return
  end

  local jsCommand = [[
document.querySelector('#audioButton').click()
]]

  helpers.runJsOnCurrentBrowserTab(jsCommand)

  local title = hs.window.focusedWindow():title()
  hs.notify
      .new({
        title = "Chrome(kasm) Mute Toggle",
        informativeText = "Muting - " .. title,
        autoWithdraw = true,
        withdrawAfter = 2,
      })
      :send()
end)

local nekoMuteToggle = helpers.hotkeyScopedToApp({ "shift", "alt" }, "m", "Google Chrome", function()
  if not (helpers.isCurrentTabUrlStartingWith("http://home:8083") or
      helpers.isCurrentTabUrlStartingWith("http://home:8084")) then
    return
  end

  local jsCommand = [[
document.querySelector('.volume').firstChild.click()
]]

  helpers.runJsOnCurrentBrowserTab(jsCommand)

  local title = hs.window.focusedWindow():title()
  hs.notify
      .new({
        title = "Chrome(n.eko) Mute Toggle",
        informativeText = "Muting - " .. title,
        autoWithdraw = true,
        withdrawAfter = 2,
      })
      :send()
end)

helpers.hotkeyScopedToApp({ "cmd" }, "c", "Books", function(app)
  app:selectMenuItem({ "Edit", "Copy" })
  local cmd = [[
pbpaste | sed -E -e 's/^[ ]?[0-9]* //g' | sed -E -e 's/“[ ]?[0-9]?[ ]?//g' | sed -E -e 's/”$//g'  | sed -E -e 's/^(Excerpt From).*//g' | pbcopy
]]
  hs.execute(cmd, true)
end)

local settingsKey = "mediaControlsEnabled"
local mediaControlsEnabled = hs.settings.get(settingsKey)
if mediaControlsEnabled == nil then mediaControlsEnabled = true end

local hotkeys = {}

hotkeys.next = hs.hotkey.bind({ "alt" }, "c", function()
  hs.eventtap.event.newSystemKeyEvent("NEXT", true):post()
  hs.eventtap.event.newSystemKeyEvent("NEXT", false):post()
end)

hotkeys.play = hs.hotkey.bind({ "alt" }, "x", function()
  hs.eventtap.event.newSystemKeyEvent("PLAY", true):post()
  hs.eventtap.event.newSystemKeyEvent("PLAY", false):post()
end)

hotkeys.prev = hs.hotkey.bind({ "alt" }, "z", function()
  hs.eventtap.event.newSystemKeyEvent("PREVIOUS", true):post()
  hs.eventtap.event.newSystemKeyEvent("PREVIOUS", false):post()
end)

local function applyMediaState(state, silent)
  for _, hk in pairs(hotkeys) do
    if state then hk:enable() else hk:disable() end
  end
  hs.settings.set(settingsKey, state)
  if not silent then
    hs.alert.show("Media controls " .. (state and "enabled" or "disabled"))
  end
end

applyMediaState(mediaControlsEnabled, true)

hs.hotkey.bind(globals.hyper, "p", function()
  mediaControlsEnabled = not mediaControlsEnabled
  applyMediaState(mediaControlsEnabled, false)
end)

-- Paste clipboard contents by simulating typing
hs.hotkey.bind(globals.hyper, "v", function()
    local text = hs.pasteboard.getContents()
    if text then
      hs.timer.doAfter(0.2, function()
        hs.eventtap.keyStrokes(text)
      end)
    end
end)

local function switchKeyboardLayout()
  local layouts = { "U.S.", "Swedish", "Turkish Q" }
  local currentLayout = hs.keycodes.currentLayout()
  local currentIndex = nil

  -- Find the index of the current layout
  for i, layout in ipairs(layouts) do
    if layout == currentLayout then
      currentIndex = i
      break
    end
  end

  -- If the current layout is in the list, switch to the next one; otherwise, switch to the first one
  if currentIndex then
    local nextIndex = (currentIndex % #layouts) + 1
    hs.keycodes.setLayout(layouts[nextIndex])
  end
end

-- move all apps on current screen to next one
hs.hotkey.bind(globals.hyper, "n", function()
  local currentScreen = hs.screen.mainScreen()
  local nextScreen = currentScreen:next()

  for _, win in ipairs(hs.window.orderedWindows()) do
    if win:screen() == currentScreen then
      win:moveToScreen(nextScreen)
    end
  end
end)

hs.hotkey.bind({ "alt", "shift" }, "q", function()
  hs.execute("open ~/Desktop")
end)

hs.hotkey.bind({ "alt", "shift" }, "w", function()
  hs.execute("open ~/Downloads")
end)

hs.hotkey.bind({ "cmd", "ctrl" }, "9", switchKeyboardLayout)

hs.hotkey.bind(globals.hyper, "b", function()
  hs.application.launchOrFocus("Google Chrome")
end)

hs.hotkey.bind({ "alt", "shift", "cmd" }, "c", function()
  hs.application.launchOrFocus("Calendar")
end)

hs.hotkey.bind(globals.hyper, "c", function()
  hs.application.launchOrFocus("ChatGPT")
end)

hs.hotkey.bind(globals.hyper, "o", function()
  hs.application.launchOrFocus("Obsidian")
end)

hs.hotkey.bind(globals.hyper, "k", function()
  hs.application.launchOrFocus("Ghostty")
end)

hs.hotkey.bind(globals.hyper, "f", function()
  hs.application.launchOrFocus("FreeCAD")
end)

-- Software such as FreeCAD/Bambu Studio have cmd + I as their "import" keybinding
-- Since Amphetamine also uses cmd + I for toggling session, we monitor for
-- cmd + I and send it to the current app if applicable.
local importSupportingApps = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
  local app = hs.application.frontmostApplication()
  local keyCode = event:getKeyCode()
  local flags   = event:getFlags()

  -- check for Cmd+I
  if keyCode == hs.keycodes.map["i"] and flags.cmd then
    local apps = { 'FreeCAD', 'Bambu Studio', 'OrcaSlicer'}
    if app and hs.fnutils.contains(apps, app:name()) then
      hs.eventtap.keyStroke({"cmd"}, "i", 0, app)
      return true -- stop original event (don’t pass through)
    end
  end

  return false -- let everything else pass through
end)

importSupportingApps:start()

return { reddit, kasmMuteToggle, nekoMuteToggle, importSupportingApps }
