function spotify {
    if [[ "$(~/bin/helpers/show_private_menu_items.sh)" == "true" ]] && ~/Documents/bitbar_plugins/state-switcher.5m.py is-state-enabled spotify; then
        echo "$(~/bin/helpers/spotify.applescript | xargs -0 echo)"
    fi
    return 0
}

paths=(
spotify
~/bin/helpers/tmux_state.sh
~/bin/helpers/tmux_focus_mode.sh
~/bin/helpers/tmux_cpu_mem.sh
~/bin/helpers/tmux_bluetooth.sh
~/bin/helpers/tmux_battery.sh
~/bin/helpers/tmux_amphetamine.sh
)

res=""
for p in "${paths[@]}"
do
	res="$res $($p)"
        res=$(echo $res | xargs -0)
done
echo "$res"
