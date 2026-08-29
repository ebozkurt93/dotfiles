if [ "$(uname)" = "Darwin" ]; then
	powered=$([[ "$(blueutil --power)" == '1' ]] && echo yes || echo no)
	connected_count=$(blueutil --connected | wc -l | xargs)
else
	powered=$(timeout 1 bluetoothctl show | grep -q "Powered: yes" && echo yes || echo no)
	connected_count=$(timeout 1 bluetoothctl devices Connected | wc -l | xargs)
fi

if [[ "$powered" == 'yes' ]]; then
	if [[ ! "$connected_count" == 0 ]]; then
		echo ''
	else
		echo ''
	fi
else
	echo ''
fi

