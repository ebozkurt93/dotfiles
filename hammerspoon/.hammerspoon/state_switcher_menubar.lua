local helpers = require("helpers")

local home = os.getenv("HOME")
local binary = home .. "/bin/state-switcher"

local menu = helpers.registerMenubar(hs.menubar.new())
local refresh

local function loadStates()
  local output, success = hs.execute(string.format("%q states-json", binary), true)
  if not success then
    return nil
  end

  local states = hs.json.decode(output)
  if type(states) ~= "table" then
    return nil
  end

  return states
end

local function runCommand(args)
  hs.task.new(binary, function()
    refresh()
  end, args):start()
end

local function toggle(title, ignoreEvent)
  if ignoreEvent then
    runCommand({ "toggle", title, "ignore-event" })
  else
    runCommand({ "toggle", title })
  end
end

local function runHook(hook, title)
  runCommand({ "run_hook", hook, title })
end

-- A real tab stop (in points), so the mark lines up in the normal
-- proportional system font instead of needing a monospace font.
local stateTabStops = { { location = 220, tabStopType = "left" } }

local function buildMenu(states)
  local items = {}
  for _, state in ipairs(states) do
    local displayTitle = (state.icon and state.icon ~= "" and (state.icon .. " ") or "___") .. state.title
    local mark = state.enabled and "✅" or "❌"

    table.insert(items, {
      title = hs.styledtext.new(displayTitle .. "\t" .. mark, { paragraphStyle = { tabStops = stateTabStops, lineBreak = "clip" } }),
      fn = function() toggle(state.title) end,
      menu = {
        { title = "Run on_enabled", fn = function() runHook("on_enabled", state.title) end },
        { title = "Run on_disabled", fn = function() runHook("on_disabled", state.title) end },
        { title = "Toggle (ignore hook)", fn = function() toggle(state.title, true) end },
      },
    })
  end
  return items
end

refresh = function()
  local states = loadStates()
  if not states then
    menu:setTitle("state-switcher ?")
    return
  end

  menu:setTitle(hs.styledtext.new("", { font = { name = "Symbols Nerd Font", size = 18 } }))
  menu:setMenu(buildMenu(states))
end

helpers.onStateSwitcherChanged(refresh)

local timer = hs.timer.doEvery(60, refresh):start()
refresh()

return {
  timer = timer,
  menubar = menu,
  refresh = refresh,
}
