#!/bin/sh

rm -rf ~/.local/share/nvim/site
# depending on the need, could delete entire nvim directory
# rm -rf ~/.local/share/nvim/

echo "run :PackerInstall (multiple times if needed) and :TSUpdate in neovim to fix potential issues"
