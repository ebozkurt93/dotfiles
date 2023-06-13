#!/bin/bash

style="size=13"

value=$(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }')

if [[ $value = '0' ]]; then
	exit
fi

echo "󱈐  | font='Symbols Nerd Font' size=18"
echo "---"
echo "Refresh | refresh=true $style"

