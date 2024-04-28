#!/bin/sh

# there is a custom one that we stow
rm ~/.zprofile

# Doing the directory changes so that some of the scripts behave as expected
src_pwd="$(echo $PWD)"
cd ../scripts

echo "Handling stow"
./stow.sh
echo "Done with stow"
echo 'Go through personal.zshrc and run any subsequent comments initial install commands listed there'

echo "Creating asdf plugins"
./asdf.sh -I
echo "Done with creating asdf plugins"
echo "Installing default versions of asdf plugins"
./asdf.sh -Install
echo "Installed plugin versions"

mkdir -p ~/Documents/bitbar_plugins/tmp
mkdir -p ~/personal-repositories

cd $src_pwd
./build-neovim.sh
