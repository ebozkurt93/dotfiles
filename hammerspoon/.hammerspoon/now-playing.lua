-- menubar enable/disable
local enabled = false
local commandString = "~/Documents/bitbar_plugins/state-switcher.5m is-state-enabled spotify && [ \"$(~/bin/helpers/macos-now-playing.js | jq -r .appName)\" != \"Spotify\" ]"

local shell = "/bin/bash"
local arguments = {"-c", commandString}

local function taskCallback(exitCode, stdOut, stdErr)
  enabled = (exitCode == 0)
end

local function runTask()
  local task = hs.task.new(shell, taskCallback, arguments)
  task:start()
end

runTask()

local interval = 10
local taskTimer = hs.timer.doEvery(interval, runTask)

taskTimer:start()

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

  if enabled and decoded and decoded.title and decoded.appName ~= "Spotify" then
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
return { timer, menubar = nowPlayingMenu, enabled, taskTimer }
