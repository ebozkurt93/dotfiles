{
  description = "Development environment with Go and Make";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        # Development shell with Go and Make
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.go
              pkgs.gnumake
            ];
          };
        };
      }
    );
}
