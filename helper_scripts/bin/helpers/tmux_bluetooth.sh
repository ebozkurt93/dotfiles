if [[ "$(blueutil --power)" == '1' ]]; then
	if [[ ! "$(blueutil --connected | wc -l | xargs)" == 0 ]]; then
		echo ''
	else
		echo ''
	fi
else
	echo ''
fi

