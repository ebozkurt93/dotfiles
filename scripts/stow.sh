#!/bin/sh

cd ..

# .DS_Store files are creating issues when running stow
find . -name ".DS_Store" -delete

directories="zsh vim nvim kitty tmux fzf git asdf bitbar starship bemlo"
if [ "$1" = "-D" ]; then
  # add -D flag to unstow
  stow -D $directories
else
  stow $directories
fi