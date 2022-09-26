#!/bin/sh

directories="zsh vim tmux fzf git asdf"
if [ "$1" = "-D" ]; then
  # add -D flag to unstow
  stow -D $directories
else
  stow $directories
fi