#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname)" = "Darwin" ]; then
	charging=$(pmset -g batt | awk -F ' ' 'gsub(";", "", $0) {print "BAT:", $3, $4}')
	charging=$(echo $charging | sed -e 's/discharging//g' -e 's/charging//g' -e 's/charged/-/g' -e 's/finishing/-/g')
	# not all these operations below are probably needed anymore, but keeping them anyway for now
	pwr_source=$(pmset -g batt | cut -c 17- | sed "s/'//g" | xargs)

	if [[ "$pwr_source" =~ ^"AC Power" ]]; then
		pwr_source='󱐥'
	else
		pwr_source=''
	fi

	pwr=$(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }')
	if [[ $pwr == '1' ]]; then
		pwr='L'
	else
		pwr=''
	fi
	echo $charging $pwr $pwr_source
	exit 0
fi

battery_dir=""
for dir in /sys/class/power_supply/BAT*; do
	if [ -d "$dir" ]; then
		battery_dir="$dir"
		break
	fi
done

if [ -z "$battery_dir" ]; then
	exit 0
fi

capacity="$(cat "$battery_dir/capacity" 2>/dev/null || true)"
status="$(cat "$battery_dir/status" 2>/dev/null || true)"

if [ -z "$capacity" ]; then
	exit 0
fi

case "$status" in
	Charging) state_icon='' ;;
	Full) state_icon='-' ;;
	Discharging) state_icon='' ;;
	*) state_icon='BAT:' ;;
esac

if command -v powerprofilesctl >/dev/null 2>&1 \
	&& [ "$(powerprofilesctl get 2>/dev/null || true)" = "power-saver" ]; then
	pwr='L'
else
	pwr=''
fi

if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
	pwr_source='󱐥'
else
	pwr_source=''
fi

echo "$state_icon ${capacity}%" "$pwr" "$pwr_source"
