My dotfiles, mostly configured to be used in OSX but contains several parts which can be used in any unix system as well. 

### Overview

Most of this repo is structured to be used with [stow](https://www.gnu.org/software/stow/). The exceptions are `scripts` and `setup` folders.
`setup` contains various scripts to setup a new macOS machine from scratch.

`stow.sh` under `scripts` can be used to stow all dotfiles to their appropriate locations.

This repository also contains couple of git submodules as well, but they are not needed to use this repo. Those contain various other dotfiles and scripts that are private.

Below is the list of folders and which application the config belongs to:
- [asdf](https://asdf-vm.com/)
- [fzf](https://github.com/junegunn/fzf)
- [git](https://git-scm.com/)
- [hammerspoon](https://www.hammerspoon.org/)
- `helper_scripts` - This folder contains scripts that are symlinked under `~/bin`.
- [kitty](https://sw.kovidgoyal.net/kitty/)
- [lima](https://lima-vm.io/)
- `nvim` - [neovim](https://neovim.io/)
- `scripts` - Some scripts which'll eventually be moved under `helper_scripts`.
- `setup` - Scripts used for setting up a brand new machine.
- [starship](https://starship.rs/)
- [tmux](https://github.com/tmux/tmux)
- [vim](https://www.vim.org/) - using neovim in most machines instead of vim, therefore this is a bit stale.
- [zsh](https://www.zsh.org/)
