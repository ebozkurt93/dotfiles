{ pkgs }:
with pkgs; [
  atuin
  asdf-vm
  bat
  blueutil
  coreutils
  colima
  docker
  docker-compose
  entr
  eza
  fd
  fzf
  gawk
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

  # lsp's, formatters etc
  nil # nix language server
  nixd
  alejandra # nix formatter
  nodePackages.bash-language-server
  nodePackages.typescript-language-server
  lua-language-server
  vscode-langservers-extracted # only using vscode-json-language-server
  shfmt
]
