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
            {
              installStateSwitcher = lib.mkAfter scripts.installStateSwitcher;
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

    # Shared shape for every NixOS host -- only the host path + system
    # string actually differ between them.
    mkNixosHost = {
      hostPath,
      system,
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          hostPath
          home-manager.nixosModules.home-manager
          {
            nixpkgs.config.allowUnfree = true; # obsidian
            nixpkgs.config.input-fonts.acceptLicense = true; # Input Mono font
            # hyprmoncfg isn't in nixpkgs yet (open PR #552223); see nixos/modules/pkgs/hyprmoncfg.nix.
            nixpkgs.overlays = [
              (final: prev: {
                hyprmoncfg = prev.callPackage ./nixos/modules/pkgs/hyprmoncfg.nix {};
              })
            ];
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
              # System-wide dark default for GTK/Qt apps; needs programs.dconf.enable at the NixOS level too.
              gtk = {
                enable = true;
                theme = {
                  name = "Adwaita-dark";
                  package = pkgs.gnome-themes-extra;
                };
              };
              dconf.settings."org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark";
                gtk-theme = "Adwaita-dark";
              };
            };
          }
        ];
      };

    nixosConfigurations = {
      utm-aarch64 = self.mkNixosHost {
        hostPath = ./nixos/hosts/utm-aarch64/configuration.nix;
        system = "aarch64-linux";
      };
      # Placeholder host for task #4 (build-only CI check) -- not installed
      # anywhere yet, see nixos/hosts/x86_64-generic/hardware-configuration.nix.
      x86_64-generic = self.mkNixosHost {
        hostPath = ./nixos/hosts/x86_64-generic/configuration.nix;
        system = "x86_64-linux";
      };
    };
  };
}
