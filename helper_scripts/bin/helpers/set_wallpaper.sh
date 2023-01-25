#!/bin/sh
file_path=~/Documents/bitbar_plugins/tmp/wallpaper.txt
if [[ ! -f $file_path ]]; then
	echo invalid file path
	exit
fi
content="$(head -n 1 $file_path)"
if [[ ! "$content" =~ .(png|jpg) ]]; then
	echo invalid content in $file_path
	echo invalid content in $content
	exit
fi
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"${content}\" as POSIX file"

