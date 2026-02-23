{
  description = "AI VM Linux packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          paths = import ./packages.linux.nix { inherit pkgs; };
        in {
          vm = pkgs.buildEnv {
            name = "vm-workspace";
            inherit paths;
          };
        }
      );
    };
}
