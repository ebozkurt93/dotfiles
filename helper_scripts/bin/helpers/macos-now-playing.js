#!/usr/bin/osascript

function run() {
  const MediaRemote = $.NSBundle.bundleWithPath(
    "/System/Library/PrivateFrameworks/MediaRemote.framework/",
  );
  MediaRemote.load;

  const MRNowPlayingRequest = $.NSClassFromString("MRNowPlayingRequest");

  const appName =
    MRNowPlayingRequest.localNowPlayingPlayerPath.client.displayName;
  const infoDict = MRNowPlayingRequest.localNowPlayingItem.nowPlayingInfo;

  const title = infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoTitle");
  const album = infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoAlbum");
  const artist = infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoArtist");
  const startTime = infoDict.valueForKey(
    "kMRMediaRemoteNowPlayingInfoStartTime",
  );
  // only seems to update when media is paused
  const elapsedTime = infoDict.valueForKey(
    "kMRMediaRemoteNowPlayingInfoElapsedTime",
  );
  // Duration in seconds(as float)
  const duration = infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoDuration");
  // not sure what this maps to
  const ts = infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoTimestamp");
  const isPlaying =
    infoDict.valueForKey("kMRMediaRemoteNowPlayingInfoPlaybackRate").js > 0;

  return JSON.stringify({
    title: title.js,
    album: album.js,
    artist: artist.js,
    appName: appName.js,
    isPlaying,
    startTime: startTime.js,
    // elapsedTime: elapsedTime.js,
    duration: duration.js,
    // ts: ts.js,
  });
}
