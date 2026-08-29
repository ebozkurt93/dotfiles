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
    obsidian # pinned app, SUPER+ALT+O raise-or-launch
    freecad # pinned app, SUPER+ALT+F raise-or-launch
    gnome-calendar # pinned app, SUPER+ALT+C raise-or-launch
    (python3.withPackages (ps: [ps.evdev])) # firefox/native-host/*.py + helper_scripts/libexec/desktop/text-expander
    zip # firefox/setup.sh's bridge.xpi build step (implicit on macOS)
    cliphist # clipboard history backend for the (upcoming) clipboard panel
    ddcutil # DDC/CI external-monitor brightness control (upcoming widget)
    brightnessctl # laptop-panel brightness; XF86MonBrightness hyprland.lua binds
    playerctl # XF86Audio play/next/prev hyprland.lua binds
    adwaita-icon-theme # no cursor theme was installed at all -- fell back to the renderer's bare default. Plain default arrow, not a themed pick.
    vlc
    signal-desktop
    google-chrome
    grim # screenshot capture (helper_scripts/libexec/desktop/screenshot)
    slurp # screenshot region selection
    gpu-screen-recorder # screen recording (helper_scripts/libexec/desktop/record)
    # forces software GL to skip a failed hardware-probe warning
    (imv.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [makeWrapper];
      postFixup =
        (old.postFixup or "")
        + ''
          wrapProgram $out/bin/imv --set LIBGL_ALWAYS_SOFTWARE 1
        '';
    }))
  ]
  ++ lib.optionals (stdenv.isLinux && stdenv.hostPlatform.isx86_64) [
    # Proprietary Electron builds with no aarch64-linux package -- this
    # VM is aarch64, so these only apply once the x86_64 host (task #4,
    # not started yet) exists.
    slack
    spotify
  ]
