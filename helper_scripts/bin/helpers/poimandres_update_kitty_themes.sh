#!/bin/sh
kitty_theme_locations="$HOME/dotfiles/kitty/.config/kitty/themes"

curl https://raw.githubusercontent.com/ubmit/poimandres-kitty/main/theme/poimandres.conf > "$kitty_theme_locations/poimandres.conf"

