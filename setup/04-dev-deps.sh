#!/bin/sh

# Doing the directory changes so that some of the scripts behave as expected
cd ../scripts

echo "Handling stow"
./stow.sh
echo "Done with stow"

echo "Handling asdf"
./asdf.sh -I
echo "Done with asdf"