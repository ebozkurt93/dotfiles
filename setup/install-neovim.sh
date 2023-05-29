# version='v0.8.3'
version='v0.9.1'
# version='nightly'

function remove_neovim {
  echo "Removing neovim"
  rm ~/bin/nvim
  rm -rf ~/bin/helpers/nvim-macos
}

remove_neovim
if [ "$1" = "-R" ]; then
  exit
fi
echo "Installing neovim with version ${version}"
curl -LO https://github.com/neovim/neovim/releases/download/${version}/nvim-macos.tar.gz
tar xzf nvim-macos.tar.gz -C ~/bin/helpers
rm nvim-macos.tar.gz
ln -s ~/bin/helpers/nvim-macos/bin/nvim ~/bin/nvim
