#!/bin/sh

cd ..

# .DS_Store files are creating issues when running stow
find . -name ".DS_Store" -delete

directories="zsh vim nvim kitty tmux fzf git asdf bitbar starship bemlo helper_scripts"
if [ "$1" = "-D" ]; then
  # add -D flag to unstow
  echo "Unstowing directories: ${directories[@]}"
  stow -D $directories
else
  echo "Stowing directories: ${directories[@]}"
  stow $directories
fi