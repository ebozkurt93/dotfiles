{
  description = "AI VM Linux packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents-nix.url = "github:numtide/llm-agents.nix";
  };

  outputs = {
    self,
    nixpkgs,
    llm-agents-nix,
  }: let
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        paths = import ./packages.linux.nix {
          inherit pkgs;
          llmAgents = llm-agents-nix.packages.${system};
        };
      in {
        vm = pkgs.buildEnv {
          name = "vm-workspace";
          inherit paths;
        };
      }
    );
  };
}
