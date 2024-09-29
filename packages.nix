{ pkgs }:
with pkgs; [
  atuin
  asdf-vm
  bat
  blueutil
  colima
  entr
  fd
  fzf
  git
  gh
  gnupg
  gnugrep
  jq
  lazydocker
  lazygit
  ripgrep
  starship
  stow
  tmux
  tree
  viu
  zsh
  zsh-autosuggestions
  nil # nix language server
  alejandra # nix formatter
]
