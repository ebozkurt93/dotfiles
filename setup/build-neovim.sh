#!/bin/bash

if [[ $(uname -s) != "Darwin" ]]; then
    echo "This script is only intended to run on macOS."
    exit 1
fi

binaries=("ninja" "cmake" "gettext" "curl")
nvim_repo_dir="$HOME/personal-repositories/neovim"
selected_tag="${1:-nightly}"

function remove_neovim {
  echo "Removing neovim"
  rm ~/bin/nvim
  rm -rf ~/bin/helpers/nvim-macos
}


echo "Checking binaries needed for building neovim"
for binary in "${binaries[@]}"; do
    if command -v "$binary" &> /dev/null; then
        echo "Dependency $binary exists"
    else
        echo "Dependency $binary does not exist, installing via brew"
        brew install $binary
    fi
done

if ! [ -d "$nvim_repo_dir" ]; then
  git clone https://github.com/neovim/neovim.git $nvim_repo_dir
else
  echo $nvim_repo_dir already exists
fi
cd $nvim_repo_dir
git checkout master
git pull
git fetch --tags
git checkout $selected_tag

remove_neovim

echo 'Building neovim'
rm -r build
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/bin/helpers/nvim-macos/
make install
echo 'Built neovim'
git checkout master

echo 'Symlinking neovim'
ln -s ~/bin/helpers/nvim-macos/bin/nvim ~/bin/nvim
# todo: check if this is still needed/wanted
rm -rf ~/bin/helpers/nvim-macos/lib/nvim/parser
