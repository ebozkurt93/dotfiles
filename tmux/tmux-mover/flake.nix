{
  description = "Development environment for tmux-mover (Go)";

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

        tmux-mover = pkgs.buildGoModule {
          pname = "tmux-mover";
          version = "0.1.0";
          src = ./.;
          vendorHash = "sha256-e9hb4EAIScbwhPGctceerV7rw0e5LREV+8uS0Xv/kmM=";
        };
      in {
        packages = {
          default = tmux-mover;
          tmux-mover = tmux-mover;
        };

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.go
              pkgs.gnumake
            ];
          };
        };

        apps = {
          # Foreground TUI: `nix run github:ebozkurt93/dotfiles?dir=tmux/tmux-mover`
          default = flake-utils.lib.mkApp {drv = tmux-mover;};

          # Headless agent watcher, detached: `nix run .#watch`
          watch = {
            type = "app";
            program = toString (pkgs.writeShellScript "tmux-mover-watch" ''
              set -euo pipefail
              log_dir="$HOME/.cache/tmux-mover"
              mkdir -p "$log_dir"
              exec nohup ${tmux-mover}/bin/tmux-mover --watch-agents >>"$log_dir/watch.log" 2>&1 &
              disown
              echo "tmux-mover --watch-agents started (log: $log_dir/watch.log)"
            '');
          };
        };
      }
    );
}
