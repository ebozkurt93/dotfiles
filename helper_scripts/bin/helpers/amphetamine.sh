#!/bin/sh


if [[ "$1" == 'i' ]]; then
	is_session_active=$(osascript -e 'tell application "Amphetamine" to set sessionActive to session is active')
	[[ "$is_session_active" == "true" ]]
	echo $?
	exit
elif [[ "$1" == '1' ]]; then
	osascript -e 'tell application "Amphetamine" to start new session'
else
	osascript -e 'tell application "Amphetamine" to end session'
fi
