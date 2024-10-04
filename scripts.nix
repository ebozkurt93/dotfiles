{
  lib,
  pkgs,
  ...
}: {
  installTPM = let
    requiredPackages = with pkgs; [git tmux gawk];
  in ''
    export PATH=${lib.makeBinPath requiredPackages}:$PATH

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi

    $HOME/.tmux/plugins/tpm/bin/clean_plugins
    $HOME/.tmux/plugins/tpm/bin/install_plugins
  '';
}
