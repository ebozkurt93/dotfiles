local helpers = require("helpers")

local enabled = false
local commandString = "~/bin/state-switcher is-state-enabled spotify && [ \"$(~/bin/helpers/macos-now-playing.js | jq -r .appName)\" == \"Spotify\" ]"

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

local spotifyMenuItems = {
  { title = "Play/Pause", fn = hs.spotify.playpause },
  { title = "Next Track", fn = hs.spotify.next },
  { title = "Previous Track", fn = hs.spotify.previous },
  {
    title = "Open Spotify",
    fn = function()
      local spotifyApp = hs.application.get("Spotify")
      if spotifyApp then
        spotifyApp:activate()
      end
    end,
  },
  {
    title = "Kill Spotify",
    fn = function()
      local spotifyApp = hs.application.get("Spotify")
      if spotifyApp then
        spotifyApp:kill()
      end
    end,
  },
}

local spotifyStatus = nil

local function updateSpotifyStatus()
  local spotifyApp = hs.application.get("Spotify")

  if enabled and spotifyApp and spotifyApp:isRunning() then
    if not spotifyStatus then
      spotifyStatus = helpers.registerMenubar(hs.menubar.new(true, "eb-spotify-status"))
    end
    spotifyStatus:setMenu(spotifyMenuItems)

    local isPlaying = hs.spotify.isPlaying() and '' or '󰏤 '
    local currentTrack = hs.spotify.getCurrentTrack()
    local currentArtist = hs.spotify.getCurrentArtist()

    spotifyStatus:setTitle("󰓇  " .. isPlaying .. currentArtist .. " - " .. currentTrack)
  else
    if spotifyStatus then
      spotifyStatus:delete()
      spotifyStatus = nil
    end
  end
end

local timer = hs.timer.doEvery(1, updateSpotifyStatus):start()

return { timer, enabled, taskTimer }
