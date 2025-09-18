#!/usr/bin/env bash

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

# Marquee: windows 0..(len-width), then jump to 0. Handles step >= positions.
# usage: scroll_marquee_step <width> <key> <chars_per_tick>
scroll_marquee_step() {
  local width=${1:-30} key=${2:-default} step=${3:-1}
  local s len positions max_off state off prev_hash hash eff next_off show_off

  IFS= read -r s || s=""
  len=${#s}
  (( step < 1 )) && step=1

  if command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$s" | shasum -a 1 | awk '{print $1}')"
  else
    hash="$(printf '%s' "$s" | cksum | awk '{print $1}')"
  fi

  state="/tmp/tmux_scroll_${key}.state"

  if (( len <= width )); then
    printf '%s\n' "$s"
    printf '0 %s\n' "$hash" > "$state"
    return 0
  fi

  positions=$(( len - width + 1 ))
  max_off=$(( positions - 1 ))

  if [[ -r "$state" ]]; then
    IFS=' ' read -r off prev_hash < "$state"
  else
    off=0 prev_hash=""
  fi
  [[ "$off" =~ ^[0-9]+$ ]] || off=0

  if [[ "$hash" != "$prev_hash" ]]; then
    off=0
  fi
  (( off > max_off )) && off=$max_off
  (( off < 0 )) && off=0

  eff=$(( step % positions ))
  if (( eff == 0 )); then
    # toggle between start and end: 0 <-> max_off
    if (( off == 0 )); then
      show_off=0
      next_off=$max_off
    else
      show_off=$max_off
      next_off=0
    fi
  else
    if (( off + eff > max_off )); then
      show_off=$max_off
      next_off=0
    else
      show_off=$off
      next_off=$(( off + eff ))
    fi
  fi

  printf '%s\n' "${s:show_off:width}"
  printf '%s %s\n' "$next_off" "$hash" > "$state"
}

media_scrolled() { media | scroll_marquee_step 50 media 4; }

paths=(
  media_scrolled
  ~/bin/helpers/tmux_state.sh
  ~/bin/helpers/tmux_focus_mode.sh
  ~/bin/helpers/tmux_bluetooth.sh
  ~/bin/helpers/tmux_battery.sh
  ~/bin/helpers/tmux_amphetamine.sh
)

res=()
for p in "${paths[@]}"; do
  out="$("$p" 2>/dev/null | tr '\n' ' ')"
  out="$(printf '%s' "$out" | sed -E 's/[[:space:]]+/ /g; s/^ | $//g')"
  [[ -n $out ]] && res+=("$out")
done

printf '%s\n' "${res[*]}"

