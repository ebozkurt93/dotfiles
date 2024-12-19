#!/bin/zsh

# Source critical configuration files
if [ -f /etc/profile ]; then
  source /etc/profile
fi

if [ -f ~/.zprofile ]; then
  source ~/.zprofile
fi

if [ -f ~/.zshrc ]; then
  source ~/.zshrc
fi

# Ensure PATH includes Nix profile paths
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Start tmux or fallback to zsh
if command -v tmux > /dev/null 2>&1; then
  tmux attach || exec /bin/zsh
else
  exec /bin/zsh
fi
