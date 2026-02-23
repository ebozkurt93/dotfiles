{ pkgs }:
with pkgs; [
  atuin
  bat
  coreutils
  curl
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
  gnutar
  jq
  yq
  lazydocker
  lazygit
  mise
  moreutils
  ripgrep
  starship
  stow
  tmux
  tree
  viu
  zsh
  zsh-autosuggestions
  direnv
  nix-direnv

  age
  sops

  # lsp's, formatters etc
  nil # nix language server
  nixd
  alejandra # nix formatter
  nodePackages.bash-language-server
  nodePackages.typescript-language-server
  lua-language-server
  vscode-langservers-extracted # only using vscode-json-language-server
  shfmt
  postgresql_16 # for psql
  tree-sitter
  sqlite

  # build tools for native plugins (e.g., telescope-fzf-native.nvim)
  gcc
  gnumake
  cmake
  pkg-config

  # editors
  neovim

  # ai
  opencode
]
