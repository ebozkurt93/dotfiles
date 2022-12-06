#!/bin/sh
kitty_theme_locations="$HOME/dotfiles/kitty/.config/kitty/themes"
variants=('nightfox' 'dawnfox' 'duskfox' 'terafox' 'carbonfox')

for p in ${variants[@]}; do
	echo $p
	curl https://raw.githubusercontent.com/EdenEast/nightfox.nvim/main/extra/$p/nightfox_kitty.conf > "$kitty_theme_locations/$p.conf"
done
