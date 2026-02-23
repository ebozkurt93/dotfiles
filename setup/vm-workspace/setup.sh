#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${AI_VM_NAME:-${HOOK_VM_NAME:-}}"
if [[ -z "$VM_NAME" ]]; then
	echo "error: AI_VM_NAME or HOOK_VM_NAME is required" >&2
	exit 1
fi

# Copy dotfiles into VM
limactl shell "$VM_NAME" -- bash -lc 'rm -rf ~/dotfiles && mkdir -p ~/dotfiles'
limactl copy "$HOME/dotfiles/." "${VM_NAME}:~/dotfiles" >/dev/null

# Install packages via Linux flake, then stow and mise
limactl shell "$VM_NAME" -- bash -s <<'SCRIPT'
  set -euo pipefail

  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi

  if ! command -v nix >/dev/null 2>&1; then
    echo "error: nix not found" >&2
    exit 1
  fi

  if [ ! -d "$HOME/dotfiles/setup/vm-workspace" ]; then
    echo "error: expected $HOME/dotfiles/setup/vm-workspace to exist" >&2
    exit 1
  fi

  nix profile add "$HOME/dotfiles/setup/vm-workspace#vm"

  cd "$HOME/dotfiles/scripts"
  ./stow.sh

  if command -v mise >/dev/null 2>&1; then
    mise trust --all --yes -C "$HOME/dotfiles"
    mise install
  fi

  if command -v nvim >/dev/null 2>&1; then
    export LD_LIBRARY_PATH="$HOME/.nix-profile/lib:${LD_LIBRARY_PATH:-}"
    nvim --headless "+Lazy! restore" +qa
  fi

  if command -v zsh >/dev/null 2>&1; then
    ZSH_PATH="$(command -v zsh)"

    if ! grep -qx "$ZSH_PATH" /etc/shells; then
      if sudo -n true 2>/dev/null; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
      fi
    fi

    if sudo -n true 2>/dev/null; then
      sudo usermod -s "$ZSH_PATH" "$USER" || true
    fi

    touch "$HOME/.bashrc"
    if ! grep -q "AI_VM_ZSH_TRAMPOLINE_BEGIN" "$HOME/.bashrc"; then
      block_file="$(mktemp)"
      cat > "$block_file" <<'EOF'
# AI_VM_ZSH_TRAMPOLINE_BEGIN
# AI_VM_NIX_PROFILE
# Ensure Nix profile is available in interactive shells.
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
# AI_VM_ZSH_TRAMPOLINE
# If this session is interactive and zsh exists, switch to zsh login shell.
case "$-" in
  *i*)
    if [ -x "$HOME/.nix-profile/bin/zsh" ] && [ -z "${ZSH_VERSION:-}" ]; then
      exec "$HOME/.nix-profile/bin/zsh" -l
    fi
  ;;
esac
# AI_VM_ZSH_TRAMPOLINE_END
EOF

      awk -v block_file="$block_file" '
        {
          print
          if ($0 ~ /\*\) return;;/) {
            in_guard=1
          } else if (in_guard && $0 ~ /^esac$/ && inserted==0) {
            while ((getline line < block_file) > 0) print line
            close(block_file)
            inserted=1
            in_guard=0
          }
        }
        END {
          if (inserted==0) {
            while ((getline line < block_file) > 0) print line
            close(block_file)
          }
        }
      ' "$HOME/.bashrc" > "$HOME/.bashrc.tmp"
      mv "$HOME/.bashrc.tmp" "$HOME/.bashrc"
      rm -f "$block_file"
    fi

    touch "$HOME/.bash_profile"
    if ! grep -q "AI_VM_BASH_PROFILE" "$HOME/.bash_profile"; then
      cat >> "$HOME/.bash_profile" <<'EOF'
# AI_VM_BASH_PROFILE
# Ensure login shells source ~/.bashrc for zsh trampoline.
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
    fi

    touch "$HOME/.zshenv"
    if ! grep -q "AI_VM_ZSHENV" "$HOME/.zshenv"; then
      cat >> "$HOME/.zshenv" <<'EOF'
# AI_VM_ZSHENV
# Ensure Nix profile is available in zsh.
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
# Keep SHELL consistent inside the VM.
if [ -x "$HOME/.nix-profile/bin/zsh" ]; then
  export SHELL="$HOME/.nix-profile/bin/zsh"
fi
EOF
    fi
  fi
SCRIPT

echo "OK: VM setup complete for $VM_NAME"
