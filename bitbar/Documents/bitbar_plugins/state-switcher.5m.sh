#!/bin/zsh

source ~/.zprofile

style="size=13"
config_file="$HOME/dotfiles/bitbar/Documents/bitbar_plugins/tmp/states.json"

titles_temp=$(cat "$config_file" | jq -r '.[].title')
icons_temp=$(cat "$config_file" | jq -r '.[].icon')
paths_temp=$(cat "$config_file" | jq -r '.[].paths')
while read -r line; do states+=("$line"); done <<<"$titles_temp"
while read -r line; do _icons+=("$line"); done <<<"$icons_temp"
while read -r line; do _paths+=("$line"); done <<<"$paths_temp"
typeset -A icons 
typeset -A paths 
for ((idx=1; idx<=${#states[@]}; ++idx)); do
  icons+=("${states[idx]}" "${_icons[idx]}")
  paths+=("${states[idx]}" "$(envsubst <<< "${_paths[idx]}")")
done

function get_file_path {
  echo ~/Documents/bitbar_plugins/tmp/$1
}

if [ "$1" = 'enabled-states' ]; then
  selected=''
  for state in "${states[@]}"; do
    file_path=`get_file_path $state`
	test ! -f $file_path || selected="$selected $state"
  done
  echo $selected
  exit
fi

if [ "$1" = 'enabled-states-short' ]; then
  for state in "${states[@]}"; do
    file_path=`get_file_path $state`
	if [[ -f $file_path ]]; then
		new=$(test -z "$icons[$state]" && echo "$state" || echo "$icons[$state]")
		selected="$selected $new"
	fi
  done
  echo $selected
  exit
fi

if [ "$1" = 'is-state-enabled' ]; then
  [[ " $($0 enabled-states) " =~ " $2 " ]]
  exit $?
fi

if [ "$1" = 'enabled-states-paths' ]; then
  for state in "${states[@]}"; do
    file_path=`get_file_path $state`
	if [[ -f $file_path ]]; then
		new=$(test -z "$icons[$state]" && echo "" || echo "$paths[$state]")
		selected="$selected $new"
	fi
  done
  echo $selected
  exit
fi

if [ "$1" = 'state-paths' ]; then
  echo "$paths[$2]"
  exit
fi

if [ "$1" = 'states' ]; then
  echo ${states[@]}
  exit
fi


if [ "$1" = 'toggle' ]; then
  file_path=`get_file_path $2`
  echo $file_path
  if printf '%s\0' "${states[@]}" | grep -Fxqz -- "$2"; then
      test -f $file_path && rm $file_path || touch $file_path
    if [ "$3" != 'no-restart' ]; then
      # kill BitBar
      ps -ef | grep "BitBar.app" | awk '{print $2}' | xargs kill 2> /dev/null
      # restart BitBar
      open -a /Applications/BitBar.app
	  exit
    fi
  fi
fi

echo "✅"
echo "---"
for state in "${states[@]}"; do
  file_path=`get_file_path $state`
  content=$(test -z "$icons[$state]" && echo "___$state" || echo "$icons[$state] $state")

  echo -e "$content\\t$(test -f $file_path && echo ✅ || echo ❌) |\
   bash=\"$0\" param1=toggle param2=$state terminal=false $style"
  echo -e "$content\\t$(test -f $file_path && echo ✅ || echo ❌) |\
   bash=\"$0\" param1=toggle param2=$state param3=no-restart alternate=true refresh=true terminal=false $style"
done
echo "Refresh | refresh=true $style"

