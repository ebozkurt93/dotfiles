{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: {
    homeConfigurations = {
      erdembozkurt = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;

        modules = [
          (
            {pkgs, ...}: {
              home = {
                packages = with pkgs; [
                  hello

                  atuin
                  # todo: replace asdf entirely
                  asdf-vm
                  bat
                  blueutil

                  entr
                  fd
                  fzf
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

                  nil # nix language server
                  # nixfmt-rfc-style
                  alejandra # nix formatter
                ];
                stateVersion = "24.05";
                username = "erdembozkurt";
                homeDirectory = "/Users/erdembozkurt";
              };
            }
          )
        ];
      };
    };
  };
}
