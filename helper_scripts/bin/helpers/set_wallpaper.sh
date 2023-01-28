#!/bin/sh
file_path=~/Documents/bitbar_plugins/tmp/wallpaper.txt

function set_wallpaper() {
	osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"${1}\" as POSIX file"
}

if [[ "$1"  == "default" ]]; then
	set_wallpaper "/System/Library/Desktop Pictures/Chroma Red.heic"
	exit
fi

if [[ "$1"  == "find" ]]; then
	echo "$(find -E $(cd ~/Downloads; pwd -P) -regex '.*\.(jpg|png|heic)')"
	exit
fi

if [[ "$1"  == "wp-path" ]]; then
	echo $file_path
	exit
fi

if [[ ! -f $file_path ]]; then
	echo invalid file path
	exit
fi
content="$(head -n 1 $file_path)"
if [[ ! "$content" =~ .(png|jpg|heic) ]]; then
	echo invalid content in $file_path
	echo invalid content in $content
	exit
fi

set_wallpaper $content

