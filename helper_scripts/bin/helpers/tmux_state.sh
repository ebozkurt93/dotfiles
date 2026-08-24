#!/usr/bin/env bash

set -euo pipefail

state_switcher="$HOME/bin/state-switcher"
if [ ! -x "$state_switcher" ]; then
	exit 0
fi

states=($("$state_switcher" enabled-states))
results=''
for state in "${states[@]}"; do
	p="$HOME/bin/helpers/tmux_$state.sh"
	if [ -f "$p" ]; then
		results="$results $($p)"
	fi
done

echo "$results"
