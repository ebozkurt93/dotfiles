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
    ...
  }: {
    darwinBase = {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      modules = [
        (
          {
            pkgs,
            lib,
            ...
          }: {
            home = {
              packages = import ./packages.nix {inherit pkgs;};
              stateVersion = "24.05";
              activation = lib.mkMerge [
                (lib.optionalAttrs (pkgs ? tmux) {
                  installTPM = lib.mkAfter ''
                    ${let scripts = import ./scripts.nix {inherit lib pkgs;}; in scripts.installTPM}
                  '';
                })
              ];
            };
          }
        )
      ];
    };

    homeConfigurations = {
      erdembozkurt = home-manager.lib.homeManagerConfiguration (self.darwinBase
        // {
          modules =
            self.darwinBase.modules
            ++ [
              ({...}: {
                home = {
                  username = "erdembozkurt";
                  homeDirectory = "/Users/erdembozkurt";
                };
              })
            ];
        });
    };
  };
}
