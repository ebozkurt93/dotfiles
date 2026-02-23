#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${AI_VM_NAME:-${HOOK_VM_NAME:-}}"
if [[ -z "$VM_NAME" ]]; then
	echo "error: AI_VM_NAME or HOOK_VM_NAME is required" >&2
	exit 1
fi

limactl shell "$VM_NAME" -- bash -lc 'rm -rf ~/workspace/CV && mkdir -p ~/workspace'
limactl copy "$HOME/personal-repositories/neovim" "${VM_NAME}:~/workspace/" >/dev/null

echo "OK: workspace copied to ~/workspace/neovim in $VM_NAME"
