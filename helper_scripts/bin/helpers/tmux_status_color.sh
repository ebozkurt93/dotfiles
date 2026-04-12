#!/usr/bin/env bash

# Setting tmux status bar colors based on kitty theme colors.
# This script is optimized to be fast and not source .zshrc

theme_file="$HOME/.config/kitty/current-theme.conf"
[[ -f "$theme_file" ]] || exit 0

bg=$(grep '^background' "$theme_file" | awk '{print $2}')
fg=$(grep '^foreground' "$theme_file" | awk '{print $2}')

[[ -n "$bg" ]] && tmux set -g status-bg "$bg"
[[ -n "$fg" ]] && tmux set -g status-fg "$fg"

if [[ ! "$bg" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  tmux set -gu pane-active-border-style
  tmux set -gu pane-border-style
  exit 0
fi

bg_r=$(printf '%d' "0x${bg:1:2}")
bg_g=$(printf '%d' "0x${bg:3:2}")
bg_b=$(printf '%d' "0x${bg:5:2}")

# Pick the accent color (color1-color6) most distinct from both bg and fg.
# Inactive border will be fg, so the active border must stand out against both.
# Score = min(distance_from_bg, distance_from_fg) — maximizing this ensures
# the active color is never too close to either extreme.
bg_lum=$(( (2126 * bg_r + 7152 * bg_g + 722 * bg_b) / 10000 ))
fg_lum=0
if [[ "$fg" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  fg_lum=$(( (2126 * $(printf '%d' "0x${fg:1:2}") + 7152 * $(printf '%d' "0x${fg:3:2}") + 722 * $(printf '%d' "0x${fg:5:2}")) / 10000 ))
fi

best_color=""
best_score=0
for i in 1 2 3 4 5 6; do
  c=$(grep "^color$i " "$theme_file" | awk '{print $2}')
  [[ -z "$c" || ! "$c" =~ ^#[0-9a-fA-F]{6}$ ]] && continue
  cr=$(printf '%d' "0x${c:1:2}")
  cg=$(printf '%d' "0x${c:3:2}")
  cb=$(printf '%d' "0x${c:5:2}")
  lum=$(( (2126 * cr + 7152 * cg + 722 * cb) / 10000 ))
  d_bg=$(( lum > bg_lum ? lum - bg_lum : bg_lum - lum ))
  d_fg=$(( lum > fg_lum ? lum - fg_lum : fg_lum - lum ))
  score=$(( d_bg < d_fg ? d_bg : d_fg ))
  if (( score > best_score )); then
    best_score=$score
    best_color=$c
  fi
done

if [[ -z "$best_color" ]]; then
  tmux set -gu pane-active-border-style
  tmux set -gu pane-border-style
  exit 0
fi

tmux set -g pane-active-border-style "fg=$best_color"
# Inactive border: fg color — readable on bg, less prominent than the active accent
if [[ -n "$fg" ]]; then
  tmux set -g pane-border-style "fg=$fg"
else
  tmux set -gu pane-border-style
fi
