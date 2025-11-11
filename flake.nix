{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bw-nixpkgs.url = "github:NixOS/nixpkgs/0cb2fd7c59fed0cd82ef858cbcbdb552b9a33465";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    bw-nixpkgs,
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
            home = let
              packages = import ./packages.nix {inherit pkgs;};
            in {
              inherit packages;
              stateVersion = "24.05";
              activation = let
                scripts = import ./scripts.nix {inherit lib pkgs;};
              in
                lib.mkMerge [
                  (lib.optionalAttrs (lib.elem pkgs.tmux packages) {
                    installTPM = lib.mkAfter scripts.installTPM;
                  })
                  {
                    installStateSwitcher = lib.mkAfter scripts.installStateSwitcher;
                  }
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
              ({pkgs, ...}: {
                home = {
                  username = "erdembozkurt";
                  homeDirectory = "/Users/erdembozkurt";
                  packages = [
                    bw-nixpkgs.legacyPackages.aarch64-darwin.bitwarden-cli
                    pkgs.openscad
                    # openscad is provided as macos app, not executable binary
                    (pkgs.writeShellScriptBin "openscad" ''
                      exec "${pkgs.openscad}/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" "$@"
                    '')
                    pkgs.syncthing
                  ];
                };
              })
            ];
        });
    };
  };
}
