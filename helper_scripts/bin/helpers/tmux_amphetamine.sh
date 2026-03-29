#!/usr/bin/env bash

set -euo pipefail

[[ "$(~/bin/helpers/amphetamine.sh i)" == "0" ]] || exit 0

remaining="$(bkt --ttl 60s --stale 10s --scope tmux-amphetamine -- ~/bin/helpers/amphetamine.sh remaining)"

if [[ "$remaining" =~ ^[0-9]+$ ]] && (( remaining > 0 )); then
  minutes=$(((remaining + 59) / 60))
  printf '󰹑 %sm\n' "$minutes"
else
  printf '󰹑\n'
fi
