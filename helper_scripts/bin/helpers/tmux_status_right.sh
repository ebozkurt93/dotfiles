media() {
  if ~/Documents/bitbar_plugins/state-switcher.5m is-state-enabled spotify; then
    json="$(~/bin/helpers/macos-now-playing.js)"
    if [ "$(jq -r '.appName // ""' <<<"$json")" = "Spotify" ]; then
      ~/bin/helpers/spotify.applescript
    else
      jq -r '
        if (.title?) then
          ( (if .isPlaying then "" else "󰏤 " end)
            + (if (.artist? and .artist != "" and .artist != "Unknown") then (.artist + " - ") else " " end)
            + .title )
        else
          ""
        end
      ' <<<"$json"
    fi
  fi
  return 0
}

paths=(
media
~/bin/helpers/tmux_state.sh
~/bin/helpers/tmux_focus_mode.sh
# ~/bin/helpers/tmux_cpu_mem.sh
~/bin/helpers/tmux_bluetooth.sh
~/bin/helpers/tmux_battery.sh
~/bin/helpers/tmux_amphetamine.sh
)

res=""
for p in "${paths[@]}"
do
	res="$res $($p)"
        res=$(echo $res | xargs -0)
done
echo "$res"
