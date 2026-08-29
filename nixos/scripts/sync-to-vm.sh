#!/usr/bin/env bash
# Syncs the working tree (including .git) to the running utm-aarch64 VM.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SSH_PORT="${SSH_PORT:-2222}"
SSH_USER="${SSH_USER:-erdembozkurt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/nixos_vm_utm}"

rsync -avz --delete \
  --exclude 'nixos/hosts/*/hardware-configuration.nix' \
  -e "ssh -p $SSH_PORT -i $SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
  "$REPO/" "$SSH_USER@localhost:/home/$SSH_USER/dotfiles/"

echo "Synced (including .git). On the VM: cd ~/dotfiles && ./scripts/stow.sh && hyprctl reload"
echo "(sudo nixos-rebuild switch --flake .#utm-aarch64 if packages.nix or a host config changed)"
