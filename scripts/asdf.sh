#!/bin/sh

plugins_filename="asdf_plugins.txt"
tool_versions_filename="../asdf/.tool-versions"

if [ "$1" = "-E" ]; then
	asdf plugin list --urls | tr -s " " " " > $plugins_filename
elif [ "$1" = "-I" ]; then
	plugins=$(cat $plugins_filename)
	IFS=$'\n'
	for plugin in $plugins
	do
		echo Installing plugin $plugin
		# for some reason piping plugin here gives a regex error with asdf, with xargs we are trimming spaces
		echo $plugin | xargs asdf plugin add
	done
elif [ "$1" = "-Install" ]; then
	plugins=$(cat $tool_versions_filename)
	IFS=$'\n'
	for plugin in $plugins
	do
		echo Installing plugin with version $plugin
		# for some reason piping plugin here gives a regex error with asdf, with xargs we are trimming spaces
		echo $plugin | xargs asdf install
	done
else
	echo "Invalid command, pass '-E' flag for exporting, '-I' flag for importing or '-Install' command for installing default versions"
	exit 1
fi
