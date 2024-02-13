-- menubar enable/disable
local enabled = false
local commandString = "~/bin/helpers/show_private_menu_items.sh"

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

-- menubar contents
local spotifyStatus = hs.menubar.new()

local function updateSpotifyStatus()
  local spotifyApp = hs.application.get("Spotify")

  if enabled and spotifyApp and spotifyApp:isRunning() then
    local isPlaying = hs.spotify.isPlaying() and '' or '󰏤 '
    local currentTrack = hs.spotify.getCurrentTrack()
    local currentArtist = hs.spotify.getCurrentArtist()

    spotifyStatus:setTitle("󰓇  " .. isPlaying .. currentTrack .. " - " .. currentArtist)
    spotifyStatus:returnToMenuBar()
  else
    spotifyStatus:setTitle("Spotify status disabled")
    spotifyStatus:removeFromMenuBar()
  end
end

local timer = hs.timer.doEvery(1, updateSpotifyStatus):start()

spotifyStatus:setMenu({
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
})

return { timer, spotifyStatus, enabled, taskTimer }
