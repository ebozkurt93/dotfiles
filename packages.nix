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
    ghostty # installed via Homebrew on macOS instead
    firefox-devedition # baseline graphical browser for the NixOS VM
    kitty # installed via Homebrew on macOS instead
    neovim # built from source via setup/build-neovim.sh on macOS instead
    xdg-utils # xdg-open and default-app helpers for the desktop session
    libnotify # notify-send; tmux-mover notification fallback on Linux
    mako # notification daemon that actually renders notify-send calls
    pavucontrol # PipeWire/PulseAudio mixer UI
    hypridle # idle daemon for lock and display sleep behavior
    wl-clipboard # helper_scripts/bin/pbcopy + pbpaste on Wayland
    xclip # helper_scripts/bin/pbcopy + pbpaste
    gnumake # telescope-fzf-native.nvim build step
    gcc # telescope-fzf-native.nvim build step
    libqalculate # qalc for launcher calculator workflows
    sqlite # telescope-all-recent.nvim (sqlite.lua)
    libsecret # secret-tool, helper_scripts/bin/helpers/pass.sh on Linux
    wireguard-tools # wg, wg-quick; helper_scripts/bin/wg-manager
    power-profiles-daemon # powerprofilesctl; helper_scripts/bin/helpers/low-power-mode-toggle.sh
    bluez # bluetoothctl; helper_scripts/bin/helpers/tmux_bluetooth.sh
    lua5_4 # sandboxed hyprland.lua replay for helper_scripts/libexec/desktop/keybinds
  ]
