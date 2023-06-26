paths=(
~/bin/helpers/tmux_state.sh
~/bin/helpers/tmux_focus_mode.sh
~/bin/helpers/tmux_cpu_mem.sh
~/bin/helpers/tmux_bluetooth.sh
~/bin/helpers/tmux_battery.sh
)

res=""
for p in "${paths[@]}"
do
	res="$res $($p)"
done
echo "$res"
