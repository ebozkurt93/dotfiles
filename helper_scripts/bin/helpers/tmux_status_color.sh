#!/usr/bin/env bash

# Setting tmux status bar colors based on kitty theme colors.
# This script is optimized to be fast and not source .zshrc

theme_file="$HOME/.config/kitty/current-theme.conf"

if [[ -f "$theme_file" ]]; then
  bg=$(grep '^background' "$theme_file" | awk '{print $2}')
  fg=$(grep '^foreground' "$theme_file" | awk '{print $2}')
  
  [[ -n "$bg" ]] && tmux set -g status-bg "$bg"
  [[ -n "$fg" ]] && tmux set -g status-fg "$fg"
fi