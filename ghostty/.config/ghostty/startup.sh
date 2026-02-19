#!/bin/zsh

# Ensure PATH includes Nix profile paths first so we can find tmux and other tools
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Source critical configuration files for environment setup
if [ -f /etc/profile ]; then
  source /etc/profile
fi

if [ -f ~/.zprofile ]; then
  source ~/.zprofile
fi

# Note: We do NOT source .zshrc here.
# The final exec zsh (or tmux shell) will handle it.
# Sourcing it here caused double-sourcing and "command not found" errors
# because PATH wasn't fully ready.

# Start tmux or fallback to zsh
if command -v tmux > /dev/null 2>&1; then
  # Try to attach to an existing session.
  # If attachment fails (no session), fall back to a login shell.
  tmux attach || exec /bin/zsh -l
else
  exec /bin/zsh -l
fi
