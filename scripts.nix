{
  lib,
  pkgs,
  ...
}: {
  installTPM = let
    requiredPackages = with pkgs; [git tmux gawk];
    # sh
  in ''
    export PATH=${lib.makeBinPath requiredPackages}:$PATH

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi

    $HOME/.tmux/plugins/tpm/bin/clean_plugins
    $HOME/.tmux/plugins/tpm/bin/install_plugins
  '';
  installStateSwitcher = let
    requiredPackages = with pkgs; [git];
  in
    # sh
    ''
      export PATH=${lib.makeBinPath requiredPackages}:$PATH
      cd $HOME/dotfiles/bitbar/Documents/bitbar_plugins/source/state-switcher
      nix develop -c make all
    '';
  installTmuxMover = let
    requiredPackages = with pkgs; [git];
  in
    # sh
    ''
      # watch-restart backgrounds tmux-mover --watch-agents, which then runs
      # for hours/days using whatever PATH it was launched with — so it needs
      # /usr/bin, /bin (afplay, osascript, ps) and ~/.nix-profile/bin
      # (terminal-notifier) here explicitly, since home-manager's activation
      # PATH has none of them.
      export PATH=${lib.makeBinPath requiredPackages}:/usr/bin:/bin:$HOME/.nix-profile/bin:$PATH
      cd $HOME/dotfiles/tmux/tmux-mover
      nix develop -c make watch-restart
    '';
}
