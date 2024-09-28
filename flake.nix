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
                packages = import ./packages.nix {inherit pkgs;};
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
