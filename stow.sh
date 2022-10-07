#!/bin/sh

# .DS_Store files are creating issues when running stow
find . -name ".DS_Store" -delete

directories="zsh vim nvim tmux fzf git asdf bitbar"
if [ "$1" = "-D" ]; then
  # add -D flag to unstow
  stow -D $directories
else
  stow $directories
fi