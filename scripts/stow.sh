#!/bin/sh

src_pwd="$(echo $PWD)"
cd ..

# .DS_Store files are creating issues when running stow
find . -name ".DS_Store" -delete

directories="zsh vim nvim kitty tmux git mise bitbar starship personal instabee helper_scripts lima hammerspoon atuin wezterm ghostty"

if [ "$1" = "-R" ]; then
  echo "Stowing and unstowing directories: ${directories[@]}"
  cd "$src_pwd"
  $0 -D
  $0
elif [ "$1" = "-D" ]; then
  # add -D flag to unstow
  echo "Unstowing directories: ${directories[@]}"
  stow -D $directories
elif [ "$1" = "-A" ]; then
  echo "Stowing directories with --adopt: ${directories[@]}"
  stow $directories --adopt
else
  stow $directories
fi
