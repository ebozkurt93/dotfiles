#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."

# .DS_Store files are creating issues when running stow
find . -name ".DS_Store" -delete

common_directories=(
  zsh
  vim
  nvim
  kitty
  tmux
  git
  mise
  starship
  helper_scripts
  atuin
  wezterm
  ghostty
  other
)

case "$(uname)" in
  Darwin)
    directories=(
      "${common_directories[@]}"
      bitbar
      personal
      instabee
      lima
      hammerspoon
    )
    ;;
  Linux)
    directories=(
      "${common_directories[@]}"
      hyprland
      quickshell
      walker
    )
    ;;
  *)
    directories=("${common_directories[@]}")
    ;;
esac

existing_directories=()
for directory in "${directories[@]}"; do
  if [ -d "$directory" ]; then
    existing_directories+=("$directory")
  else
    echo "Skipping missing stow directory: $directory" >&2
  fi
done
directories=("${existing_directories[@]}")

mode=""
if [[ "${1:-}" == "-R" || "${1:-}" == "-D" || "${1:-}" == "-A" ]]; then
  mode="$1"
  shift
fi

stow_args=("$@")

if [ "$mode" = "-R" ]; then
  echo "Stowing and unstowing directories: ${directories[@]}"
  "$0" -D "${stow_args[@]}"
  "$0" "${stow_args[@]}"
elif [ "$mode" = "-D" ]; then
  # add -D flag to unstow
  echo "Unstowing directories: ${directories[@]}"
  stow --target="$HOME" "${stow_args[@]}" -D "${directories[@]}"
elif [ "$mode" = "-A" ]; then
  echo "Stowing directories with --adopt: ${directories[@]}"
  stow --target="$HOME" "${stow_args[@]}" --adopt "${directories[@]}"
else
  stow --target="$HOME" "${stow_args[@]}" "${directories[@]}"
fi
