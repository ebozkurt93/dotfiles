#!/bin/sh

rm -rf ~/.local/share/nvim/site
# depending on the need, could delete entire nvim directory
# rm -rf ~/.local/share/nvim/
# this is needed for the possession plugin
# mkdir -p ~/.local/share/nvim/sessions

# this could be needed so that treesitter parser takes precedence
#  https://github.com/nvim-treesitter/nvim-treesitter/issues/3970#issuecomment-1353836834
# rm -rf /opt/homebrew/Cellar/neovim/0.8.1/lib/nvim/parser
echo "run :TSUpdate in neovim to fix potential issues, necessary parsers should be installed by default but might have missed some"
