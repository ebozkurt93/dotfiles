{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bw-nixpkgs.url = "github:NixOS/nixpkgs/0cb2fd7c59fed0cd82ef858cbcbdb552b9a33465";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents-nix.url = "github:numtide/llm-agents.nix";
    quickshell.url = "github:quickshell-mirror/quickshell";
    quickshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    bw-nixpkgs,
    home-manager,
    llm-agents-nix,
    quickshell,
    ...
  }: let
    # Shared home-manager module: packages + activation scripts common to
    # every platform. Per-target modules (username, homeDirectory, extra
    # platform-only packages) get appended on top of this by each target below.
    homeModule = {
      pkgs,
      lib,
      ...
    }: {
      home = let
        packages = import ./packages.nix {
          inherit pkgs;
          llmAgents = llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system};
        };
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
            # installStateSwitcher builds the bitbar/xbar state-switcher plugin,
            # which isn't stowed on Linux yet (bitbar's Linux replacement is
            # still undecided). Re-enable here once that's sorted.
            (lib.optionalAttrs pkgs.stdenv.isDarwin {
              installStateSwitcher = lib.mkAfter scripts.installStateSwitcher;
            })
            {
              installTmuxMover = lib.mkAfter scripts.installTmuxMover;
            }
          ];
      };
    };
  in {
    darwinBase = {
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };
      modules = [homeModule];
    };

    homeConfigurations = {
      erdembozkurt = home-manager.lib.homeManagerConfiguration (self.darwinBase
        // {
          modules =
            self.darwinBase.modules
            ++ [
              ({pkgs, ...}: let
                openscad = pkgs.openscad.overrideAttrs (_: {
                  doCheck = false;
                  doInstallCheck = false;
                });
              in {
                home = {
                  username = "erdembozkurt";
                  homeDirectory = "/Users/erdembozkurt";
                  packages = [
                    bw-nixpkgs.legacyPackages.aarch64-darwin.bitwarden-cli
                    # openscad is provided as macos app, not executable binary
                    (pkgs.writeShellScriptBin "openscad" ''
                      exec "${openscad}/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" "$@"
                    '')
                    pkgs.syncthing
                  ];
                };
              })
            ];
        });
    };

    nixosConfigurations = {
      utm-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./nixos/hosts/utm-aarch64/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.config.allowUnfree = true; # obsidian
          }
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.erdembozkurt = {pkgs, ...}: {
              imports = [homeModule];
              home.username = "erdembozkurt";
              home.homeDirectory = "/home/erdembozkurt";
              # quickshell only makes sense on Linux with Hyprland, kept out
              # of the shared homeModule so darwin's package set is untouched.
              home.packages = [quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default];
            };
          }
        ];
      };
    };
  };
}
