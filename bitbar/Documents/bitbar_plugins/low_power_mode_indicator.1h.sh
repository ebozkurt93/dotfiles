#!/bin/bash

style="size=13"

os_major_version=$(sw_vers -productVersion | awk -F '.' '{print $1}')
low_power_mode=$(pmset -g | grep lowpowermode | awk -F' ' '{print $2}')

if [[ $os_major_version -ge 15 || $low_power_mode = '0' ]]; then
	exit
fi

echo "󱈐  | font='Symbols Nerd Font' size=18"
echo "---"
echo "Refresh | refresh=true $style"

