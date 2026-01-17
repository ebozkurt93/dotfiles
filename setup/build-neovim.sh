#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/2dcd9c55e8914017226f5948ac22c53872a13ee2.tar.gz
#! nix-shell -p ninja cmake gettext curl libiconv-darwin

set -euo pipefail

if [[ $(uname -s) != "Darwin" ]]; then
    echo "This script is only intended to run on macOS."
    exit 1
fi

nvim_repo_dir="$HOME/personal-repositories/neovim"
selected_tag="${1:-nightly}"

function remove_neovim {
  echo "Removing neovim"
  rm ~/bin/nvim
  rm -rf ~/bin/helpers/nvim-macos
}

if ! [ -d "$nvim_repo_dir" ]; then
  git clone https://github.com/neovim/neovim.git $nvim_repo_dir
else
  echo $nvim_repo_dir already exists
fi
cd $nvim_repo_dir
git checkout master
git pull
git fetch --tags --force
git checkout $selected_tag

remove_neovim

echo 'Building neovim'
rm -rf build
rm -rf .deps
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/bin/helpers/nvim-macos/
make install
echo 'Built neovim'
git checkout master

echo 'Symlinking neovim'
ln -s ~/bin/helpers/nvim-macos/bin/nvim ~/bin/nvim
