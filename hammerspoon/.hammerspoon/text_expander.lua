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

local function getLastXCharacters(str, x)
  return #str <= x and str or string.sub(str, -x)
end

local expander = (function()
  local word = ""
  local keyMap = require("hs.keycodes").map
  local DEBUG = false

  local keyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
    if ev:getFlags().cmd or ev:getFlags().ctrl or ev:getFlags().alt then
      return false
    end

    local keyCode = ev:getKeyCode()
    local char = ev:getCharacters()

    if keyCode == keyMap["delete"] then
      word = #word > 0 and string.sub(word, 1, -2) or ""
      return false
    end

    word = getLastXCharacters(word .. char, 20)
    local found = false

    for i = #word, 1, -1 do
      local substring = string.sub(word, i)
      if keywords[substring] then
        word = substring
        found = true
        break
      end
    end

    if keyCode == keyMap["return"] or keyCode == keyMap["space"] or keyCode == keyMap["up"]
        or keyCode == keyMap["down"] or keyCode == keyMap["left"] or keyCode == keyMap["right"]
        or keyCode == keyMap["tab"] then
      word = ""
    end

    if found then
      for _ = 1, utf8.len(word) do
        hs.eventtap.keyStroke({}, "delete", 0)
      end

      local replacement = keywords[word]
      hs.eventtap.keyStrokes(type(replacement) == "function" and replacement() or replacement)
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
