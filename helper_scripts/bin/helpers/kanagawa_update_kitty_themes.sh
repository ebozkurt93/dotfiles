#!/bin/sh
kitty_theme_locations="$HOME/dotfiles/kitty/.config/kitty/themes"

curl https://raw.githubusercontent.com/rebelot/kanagawa.nvim/master/extras/kanagawa.conf > "$kitty_theme_locations/kanagawa.conf"

