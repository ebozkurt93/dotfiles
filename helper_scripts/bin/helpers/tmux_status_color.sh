# Setting tmux status bar colors based on kitty theme colors.
# AFAIK it is not possible to set dynamic status bar colors from tmux directly,
# therefore adding them via this script

p=$(zsh -c "source ~/.zshrc; __theme_helper get_current_kitty_theme_path")

tmux set -g status-bg $(echo $p | xargs cat | grep '^background' | cut -c 12-)
tmux set -g status-fg $(echo $p | xargs cat | grep '^foreground' | cut -c 12-)

