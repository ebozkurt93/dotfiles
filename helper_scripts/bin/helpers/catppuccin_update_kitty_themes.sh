#!/bin/sh
kitty_theme_locations="$HOME/dotfiles/kitty/.config/kitty/themes"
variants=('latte' 'frappe' 'mocha' 'macchiato')
for p in ${variants[@]}; do
	echo $p
	curl https://raw.githubusercontent.com/catppuccin/kitty/main/themes/$p.conf > "$kitty_theme_locations/catppuccin-$p.conf"
done
