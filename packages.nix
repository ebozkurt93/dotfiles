{
  pkgs,
  llmAgents ? pkgs,
}:
with pkgs;
  [
    atuin
    bat
    bkt
    coreutils
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
    tree-sitter

    age
    sops

    # lsp's, formatters etc
    nil # nix language server
    nixd
    alejandra # nix formatter
    bash-language-server
    typescript-language-server
    lua-language-server
    vscode-langservers-extracted # only using vscode-json-language-server
    shfmt
    postgresql_16 # for psql

    # ai
    llmAgents.claude-code
    codex
    opencode
  ]
  ++ lib.optionals stdenv.isDarwin [
    blueutil
    colima
    lima
    terminal-notifier # tmux-mover --watch-agents banners
  ]
  ++ lib.optionals stdenv.isLinux [
    neovim # built from source via setup/build-neovim.sh on macOS instead
    xclip # helper_scripts/bin/pbcopy + pbpaste
    gnumake # telescope-fzf-native.nvim build step
    gcc # telescope-fzf-native.nvim build step
    sqlite # telescope-all-recent.nvim (sqlite.lua)
  ]
