#!/bin/sh
kitty_theme_locations="$HOME/dotfiles/kitty/.config/kitty/themes"

curl https://raw.githubusercontent.com/savq/melange/master/term/kitty/melange_dark.conf > "$kitty_theme_locations/melange-dark.conf"
curl https://raw.githubusercontent.com/savq/melange/master/term/kitty/melange_light.conf > "$kitty_theme_locations/melange-light.conf"
