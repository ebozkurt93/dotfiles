-- Modified version of https://github.com/Hammerspoon/hammerspoon/issues/1042
local helpers = require("helpers")
local _, personalKeywords = helpers.safeRequire("personal", {"expansions"}, {})

local keywords = {
  ["@@lorem"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In lobortis fermentum molestie. Vestibulum congue auctor nisi, eu ultrices lectus facilisis eu. Nulla molestie ornare massa, sed malesuada urna consequat sed. Curabitur a nibh blandit felis imperdiet interdum. Vivamus eu malesuada purus. Suspendisse in lacus non quam sagittis porttitor. In hac habitasse platea dictumst. Nullam suscipit nulla non tellus interdum faucibus. Ut eget mauris mi. Nam rhoncus quis massa sit amet placerat. Donec sollicitudin enim nec ex rutrum, in ornare arcu venenatis. Praesent consequat enim ante, et ornare eros pellentesque ut.",
  ["@alph"] = function()
    return string.rep("abcdefghijklmnopqrstuvwxyz", 3)
  end,
  ["@@ip"] = function()
    local status, body, headers = hs.http.get("https://icanhazip.com", nil)
    return string.gsub(body, "^%s*(.-)%s*$", "%1")
    --return body
  end,
  ["@@localip"] = function()
    return hs.network.interfaceDetails('en0')['IPv4']['Addresses'][1]
  end,
  ["@unixtime"] = function()
    return tostring(os.time())
  end,
  ["@@time"] = function()
    return tostring(os.date("%H:%M"))
  end,
  ["@@hlepoch"] = function()
    return tostring(os.date("%y%m%d%H%M%S"))
  end,
  ["@@hldepoch"] = function()
    return tostring(os.date("%y-%m-%d-%H:%M:%S"))
  end,
}

keywords = helpers.merge(keywords, personalKeywords)

local function getLastXCharacters(str, x)
  if #str <= x then
    return str
  else
    return string.sub(str, -x)
  end
end

expander = (function()
  local word = ""
  local keyMap = require("hs.keycodes").map
  local keyWatcher
  local DEBUG = false

  -- create an "event listener" function that will run whenever the event happens
  keyWatcher = hs.eventtap
    .new({ hs.eventtap.event.types.keyDown }, function(ev)
      local keyCode = ev:getKeyCode()
      local char = ev:getCharacters()

      -- if "delete" key is pressed
      if keyCode == keyMap["delete"] then
        if #word > 0 then
          -- remove the last char from a string with support to utf8 characters
          local t = {}
          for _, chars in utf8.codes(word) do
            table.insert(t, chars)
          end
          table.remove(t, #t)
          word = utf8.char(table.unpack(t))
          if DEBUG then
            print("Word after deleting:", word)
          end
        end
        return false -- pass the "delete" keystroke on to the application
      end

      -- append char to "word" buffer
      word = word .. char
      word = getLastXCharacters(word, 20)
      local found = false

      local length = #word
      for i = length, 1, -1 do
        local substring = string.sub(word, i, length)
        if keywords[substring] then
          word = substring
          found = true
          break
        end
      end

      -- attempt to find word from last
      if DEBUG then
        print("Word after appending:", word)
      end

      -- if one of these "navigational" keys is pressed
      if
        keyCode == keyMap["return"]
        or keyCode == keyMap["space"]
        or keyCode == keyMap["up"]
        or keyCode == keyMap["down"]
        or keyCode == keyMap["left"]
        or keyCode == keyMap["right"]
        or keyCode == keyMap["tab"]
      then
        word = "" -- clear the buffer
      end

      if DEBUG then
        print("Word to check if hotstring:", word)
      end

      -- finally, if "word" is a hotstring
      if found then
        for i = 1, utf8.len(word), 1 do
          hs.eventtap.keyStroke({}, "delete", 0)
        end -- delete the abbreviation

        if type(keywords[word]) == "function" then
          hs.eventtap.keyStrokes(keywords[word]())
        else
          hs.eventtap.keyStrokes(keywords[word]) -- expand the word
        end
        word = "" -- clear the buffer
      end

      return false -- pass the event on to the application
    end)
    :start() -- start the eventtap

  -- return keyWatcher to assign this functionality to the "expander" variable to prevent garbage collection
  return keyWatcher
end)() -- this is a self-executing function because we want to start the text expander feature automatically in out init.lua
