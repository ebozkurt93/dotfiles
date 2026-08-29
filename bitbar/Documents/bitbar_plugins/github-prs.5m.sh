#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" != "fzf" && "${1:-}" != "count" ]]; then
  [ ! -f "$HOME/.zprofile" ] || . "$HOME/.zprofile"
  # .zshrc has zsh-only syntax; a syntax error while sourcing it directly
  # would abort this whole script even with `|| true`, so isolate it in a
  # nested bash process instead.
  eval "$(bash -c '. "$HOME/.zshrc" >/dev/null 2>&1; export -p' 2>/dev/null)" || true
  PATH="${PATH}:${HOME}/.nix-profile/bin"
  "$HOME/Documents/bitbar_plugins/state-switcher.5m" is-state-enabled instabee || exit
else
  PATH="${PATH}:${HOME}/.nix-profile/bin"
fi

export GITHUB_PRS_QUERIES_FILE="${GITHUB_PRS_QUERIES_FILE:-$HOME/Documents/bitbar_plugins/tmp/queries.txt}"
export GITHUB_PRS_CACHE_FILE="${GITHUB_PRS_CACHE_FILE:-$HOME/Documents/bitbar_plugins/tmp/prs.txt}"

exec "$HOME/bin/github-prs" "${1:-bitbar}"
