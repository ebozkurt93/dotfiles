#!/bin/sh

 directories="zsh vim tmux fzf git asdf"
 stow $directories
 # add -D flag to unstow
#  stow -D $directories