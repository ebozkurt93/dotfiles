-- Config
local expandedPath = os.getenv("HOME") .. "/dotfiles/helper_scripts/bin/helpers/macos-now-playing.js"
local command = "/usr/bin/osascript " .. expandedPath

-- Menubar item
local nowPlayingMenu = hs.menubar.new()

-- Update function
local function updateNowPlaying()
  local handle = io.popen(command)
  local output = handle:read("*a")
  handle:close()

  local decoded = hs.json.decode(output)

  -- hs.alert.show(decoded)
  if decoded and decoded.title then
    local isPlaying = decoded.isPlaying and "" or "󰏤 "
    local title = decoded.title
    local artist = " "
    if decoded.artist and decoded.artist ~= "" and decoded.artist ~= "Unknown" then
      artist = decoded.artist .. " - "
    end
    nowPlayingMenu:setTitle(isPlaying .. artist .. title)
    nowPlayingMenu:returnToMenuBar()
  else
    nowPlayingMenu:setTitle("")
    nowPlayingMenu:removeFromMenuBar()
  end
end

-- Run every second
local timer = hs.timer.doEvery(1, updateNowPlaying):start()

-- Return for reusability
return { timer, menubar = nowPlayingMenu }
