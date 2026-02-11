-- Modified version of https://github.com/Hammerspoon/hammerspoon/issues/1042
local helpers = require("helpers")
local _, personalKeywords = helpers.safeRequire("personal", { "expansions" }, {})

local keywords = {
  ["@@lorem"] =
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In lobortis fermentum molestie. Vestibulum congue auctor nisi, eu ultrices lectus facilisis eu. Nulla molestie ornare massa, sed malesuada urna consequat sed. Curabitur a nibh blandit felis imperdiet interdum. Vivamus eu malesuada purus. Suspendisse in lacus non quam sagittis porttitor. In hac habitasse platea dictumst. Nullam suscipit nulla non tellus interdum faucibus. Ut eget mauris mi. Nam rhoncus quis massa sit amet placerat. Donec sollicitudin enim nec ex rutrum, in ornare arcu venenatis. Praesent consequat enim ante, et ornare eros pellentesque ut.",
  ["@alph"] = function()
    return string.rep("abcdefghijklmnopqrstuvwxyz", 3)
  end,
  ["@@ip"] = function()
    local _, body = hs.http.get("https://icanhazip.com", nil)
    return body and string.gsub(body, "^%s*(.-)%s*$", "%1") or ""
  end,
  ["@@localip"] = function()
    local details = hs.network.interfaceDetails("en0")
    return details and details.IPv4 and details.IPv4.Addresses and details.IPv4.Addresses[1] or "Unknown"
  end,
  ["@unixtime"] = function()
    return tostring(os.time())
  end,
  ["@@time"] = function()
    return os.date("%H:%M")
  end,
  ["@@d"] = function()
    return os.date("%Y-%m-%d")
  end,
  ["@@hlepoch"] = function()
    return os.date("%y%m%d%H%M%S")
  end,
  ["@@hldepoch"] = function()
    return os.date("%y-%m-%d-%H:%M:%S")
  end,
}

keywords = helpers.merge(keywords, personalKeywords)

-- Precompute trigger lengths and maximum trigger length (byte-based; triggers are ASCII)
local triggerLengths = {}
local maxTriggerLen = 0
do
  local seen = {}
  for k, _ in pairs(keywords) do
    local n = #k
    if not seen[n] then
      seen[n] = true
      table.insert(triggerLengths, n)
    end
    if n > maxTriggerLen then
      maxTriggerLen = n
    end
  end
  table.sort(triggerLengths, function(a, b) return a > b end)
end

local function lastBytes(s, n)
  if #s <= n then return s end
  return string.sub(s, -n)
end

local expander = (function()
  local word = ""
  local keyMap = require("hs.keycodes").map
  local DEBUG = false

  -- Prevent our own injected keystrokes from being re-processed.
  local injecting = false
  local function withInjection(fn)
    injecting = true
    fn()
    -- Drop the guard on the next runloop tick.
    hs.timer.doAfter(0, function() injecting = false end)
  end

  local keyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
    if injecting then
      return false
    end

    local flags = ev:getFlags()
    if flags.cmd or flags.ctrl or flags.alt then
      return false
    end

    local keyCode = ev:getKeyCode()
    local char = ev:getCharacters() or ""

    if keyCode == keyMap["delete"] then
      word = (#word > 0) and string.sub(word, 1, -2) or ""
      return false
    end

    if char ~= "" then
      word = lastBytes(word .. char, maxTriggerLen)
    else
      word = lastBytes(word, maxTriggerLen)
    end

    -- Reset on separators / navigation keys (same behavior as before)
    if keyCode == keyMap["return"] or keyCode == keyMap["space"] or keyCode == keyMap["up"]
        or keyCode == keyMap["down"] or keyCode == keyMap["left"] or keyCode == keyMap["right"]
        or keyCode == keyMap["tab"] then
      word = ""
      return false
    end

    -- Only check suffixes that can possibly match a trigger.
    local matched = nil
    for _, n in ipairs(triggerLengths) do
      if #word >= n then
        local suffix = string.sub(word, -n)
        if keywords[suffix] then
          matched = suffix
          break
        end
      end
    end

    if matched then
      local replacement = keywords[matched]
      local out = type(replacement) == "function" and replacement() or replacement

      withInjection(function()
        for _ = 1, #matched do
          hs.eventtap.keyStroke({}, "delete", 0)
        end
        hs.eventtap.keyStrokes(out)
      end)

      word = ""
    end

    return false
  end):start()

  return keyWatcher
end)()

local function showExpansionsViaChooser()
  expander:stop()
  local choices = {}
  for text, _ in pairs(keywords) do
    table.insert(choices, { text = text })
  end

  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    local word = choice.text

    local replacement = keywords[word]
    hs.eventtap.keyStrokes(type(replacement) == "function" and replacement() or replacement)
  end)

  chooser:choices(choices)
  chooser:queryChangedCallback(helpers.queryChangedCallback(chooser, choices))
  chooser:hideCallback(function() expander:start() end)
  chooser:show()
end

hs.hotkey.bind({ "cmd", "shift" }, "e", showExpansionsViaChooser)

return { expander }
