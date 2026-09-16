local helpers = require("helpers")

local enabled = false
local commandString = "~/bin/state-switcher is-state-enabled spotify && [ \"$(~/bin/helpers/macos-now-playing.js | jq -r .appName)\" != \"Spotify\" ]"

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

helpers.onStateSwitcherChanged(runTask)

local interval = 10
local taskTimer = hs.timer.doEvery(interval, runTask)

taskTimer:start()

local expandedPath = os.getenv("HOME") .. "/dotfiles/helper_scripts/bin/helpers/macos-now-playing.js"

local nowPlayingMenuItems
local nowPlayingMenu = nil
local lastDecoded = nil

local function applyNowPlaying(decoded)
  lastDecoded = decoded
  if enabled and decoded and decoded.title and decoded.appName ~= "Spotify" then
    local isPlaying = decoded.isPlaying and "" or "󰏤 "
    local title = decoded.title
    local artist = " "
    if decoded.artist and decoded.artist ~= "" and decoded.artist ~= "Unknown" then
      artist = decoded.artist .. " - "
    end
    if not nowPlayingMenu then
      nowPlayingMenu = helpers.registerMenubar(hs.menubar.new(true, "eb-now-playing"))
    end
    nowPlayingMenu:setMenu(nowPlayingMenuItems)
    nowPlayingMenu:setTitle(isPlaying .. artist .. title)
  else
    if nowPlayingMenu then
      nowPlayingMenu:delete()
      nowPlayingMenu = nil
    end
  end
end

local function updateNowPlaying()
  hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, _)
    if exitCode == 0 then
      applyNowPlaying(hs.json.decode(stdOut or ""))
    end
  end, { expandedPath }):start()
end

local function refresh()
  runTask()
  updateNowPlaying()
end

local timer = hs.timer.doEvery(1, updateNowPlaying):start()

local function findAppName()
  return lastDecoded and lastDecoded.appName
end

nowPlayingMenuItems = {
  {
    title = "Play/Pause",
    fn = function()
      hs.eventtap.event.newSystemKeyEvent("PLAY", true):post()
      hs.eventtap.event.newSystemKeyEvent("PLAY", false):post()
    end
  },
  {
    title = "Next",
    fn = function()
      hs.eventtap.event.newSystemKeyEvent("NEXT", true):post()
      hs.eventtap.event.newSystemKeyEvent("NEXT", false):post()
    end
  },
  {
    title = "Previous",
    fn = function()
      hs.eventtap.event.newSystemKeyEvent("PREVIOUS", true):post()
      hs.eventtap.event.newSystemKeyEvent("PREVIOUS", false):post()
    end
  },
  {
    title = "Open app",
    fn = function()
      local app = hs.application.get(findAppName())
      if app then
        app:activate()
      end
    end,
  },
  {
    title = "Kill app",
    fn = function()
      local app = hs.application.get(findAppName())
      if app then
        app:kill()
      end
    end,
  },
}

return { timer, enabled, taskTimer, refresh = refresh }
