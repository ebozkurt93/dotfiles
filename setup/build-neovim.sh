#!/usr/bin/env nix-shell
#!nix-shell -i bash -p ninja cmake gettext curl libiconv-darwin

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
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/bin/helpers/nvim-macos/
make install
echo 'Built neovim'
git checkout master

echo 'Symlinking neovim'
ln -s ~/bin/helpers/nvim-macos/bin/nvim ~/bin/nvim
