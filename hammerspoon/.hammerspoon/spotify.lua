local spotifyStatus = hs.menubar.new()

local function updateSpotifyStatus()
  local spotifyApp = hs.application.get("Spotify")

  if spotifyApp and spotifyApp:isRunning() then
    local currentTrack = hs.spotify.getCurrentTrack()
    local currentArtist = hs.spotify.getCurrentArtist()

    spotifyStatus:setTitle("󰓇  " .. currentTrack .. " - " .. currentArtist)
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

return { timer, spotifyStatus }
