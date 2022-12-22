#!/bin/sh

# there is a custom one that we stow
rm ~/.zprofile

# Doing the directory changes so that some of the scripts behave as expected
cd ../scripts

echo "Handling stow"
./stow.sh
echo "Done with stow"

echo "Creating asdf plugins"
./asdf.sh -I
echo "Done with creating asdf plugins"
echo "Installing default versions of asdf plugins"
./asdf.sh -Install
echo "Installed plugin versions"

mkdir -p ~/Documents/bitbar_plugins/tmp
