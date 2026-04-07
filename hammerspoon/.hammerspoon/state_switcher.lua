local helpers = require("helpers")

local home = os.getenv("HOME")
local stateSwitcherBinary = home .. "/Documents/bitbar_plugins/state-switcher.5m"
local iconCache = {}

local showMenu

local function runStateCommand(args, failureMessage)
  local task = hs.task.new(stateSwitcherBinary, function(exitCode, _stdOut, stdErr)
    if exitCode ~= 0 then
      hs.alert.show(failureMessage or "State command failed")
      if stdErr and stdErr ~= "" then
        print(stdErr)
      end
    end
  end, args)

  if not task then
    hs.alert.show(failureMessage or "Failed to start state command")
    return
  end

  task:start()
end

local function buildStateImage(state)
  local cacheKey = state.enabled and "enabled" or "disabled"

  if iconCache[cacheKey] then
    return iconCache[cacheKey]
  end

  local canvas = hs.canvas.new({ x = 0, y = 0, w = 28, h = 28 })
  canvas[1] = {
    type = "text",
    text = state.enabled and "✅" or "❌",
    textSize = 18,
    textAlignment = "center",
    frame = { x = 0, y = 1, w = 28, h = 24 },
  }

  local image = canvas:imageFromCanvas()
  iconCache[cacheKey] = image
  return image
end

local function buildChoice(state)
  return {
    text = state.title,
    image = buildStateImage(state),
    searchText = table.concat({
      state.title,
      state.icon or "",
      state.enabled and "on" or "off",
      "without hook",
      "ignore-event",
    }, " "),
    title = state.title,
    enabled = state.enabled,
  }
end

local function loadStatesFromCli()
  local output, success, _, stderr = hs.execute(string.format("%q states-json", stateSwitcherBinary), true)
  if not success then
    return nil, (stderr and stderr ~= "" and stderr) or "Failed to query state-switcher"
  end

  local states = hs.json.decode(output)
  if type(states) ~= "table" then
    return nil, "Invalid state-switcher JSON output"
  end

  local items = {}
  for _, state in ipairs(states) do
    table.insert(items, buildChoice(state))
  end

  table.sort(items, function(a, b)
    if a.enabled ~= b.enabled then
      return a.enabled and not b.enabled
    end
    return a.title < b.title
  end)

  return items
end

showMenu = function()
  local items, err = loadStatesFromCli()
  if not items then
    hs.alert.show(err)
    return
  end

  local chooser = hs.chooser.new(function(choice)
    if not choice then
      return
    end

    local modifiers = hs.eventtap.checkKeyboardModifiers()
    local alternate = modifiers.alt
    local args = alternate and { "toggle", choice.title, "ignore-event" } or { "toggle", choice.title }
    local failureMessage = alternate
      and ("Failed to toggle %s without hook"):format(choice.title)
      or ("Failed to toggle %s"):format(choice.title)

    runStateCommand(args, failureMessage)
  end)

  chooser:searchSubText(true)
  chooser:choices(items)
  chooser:queryChangedCallback(helpers.queryChangedCallback(chooser, items, "searchText"))
  chooser:show()
end

hs.hotkey.bind({ "ctrl", "shift" }, "s", showMenu)

return {
  showMenu = showMenu,
}
