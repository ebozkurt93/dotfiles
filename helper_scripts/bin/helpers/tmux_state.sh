states=($(~/Documents/bitbar_plugins/state-switcher.5m.py enabled-states))
results=''
for state in "${states[@]}"; do
	p="$HOME/bin/helpers/tmux_$state.sh"
	if [ -f "$p" ]; then
		results="$results $($p)"
	fi
done

echo "$results"
