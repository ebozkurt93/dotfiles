#!/bin/zsh

source ~/.zprofile

style="size=13"
config_file="$HOME/dotfiles/bitbar/Documents/bitbar_plugins/tmp/states.json"

titles_temp=$(cat "$config_file" | jq -r '.[].title')
icons_temp=$(cat "$config_file" | jq -r '.[].icon')
paths_temp=$(cat "$config_file" | jq -r '.[].paths')
on_enabled_temp=$(cat "$config_file" | jq -r '.[] | if has("on_enabled") then .on_enabled else "" end')
on_disabled_temp=$(cat "$config_file" | jq -r '.[] | if has("on_disabled") then .on_disabled else "" end')
while read -r line; do states+=("$line"); done <<<"$titles_temp"
while read -r line; do _icons+=("$line"); done <<<"$icons_temp"
while read -r line; do _paths+=("$line"); done <<<"$paths_temp"
while read -r line; do _on_enabled+=("$line"); done <<<"$on_enabled_temp"
while read -r line; do _on_disabled+=("$line"); done <<<"$on_disabled_temp"
typeset -A icons
typeset -A paths
typeset -A on_enabled_commands
typeset -A on_disabled_commands
for ((idx=1; idx<=${#states[@]}; ++idx)); do
  icons+=("${states[idx]}" "${_icons[idx]}")
  paths+=("${states[idx]}" "$(envsubst <<< "${_paths[idx]}")")
  on_enabled_commands+=("${states[idx]}" "${_on_enabled[idx]}")
  on_disabled_commands+=("${states[idx]}" "${_on_disabled[idx]}")
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
      # new=$(test -z "$icons[$state]" && echo "$state" || echo "$icons[$state]")
      new="$icons[$state]"
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
      new=$(test -z "$paths[$state]" && echo "" || echo "$paths[$state]")
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

if [ "$1" = 'states-with-marks' ]; then
  for state in "${states[@]}"; do
    file_path=`get_file_path $state`
    printf "%-20s %-10s\n" "$state" "$(test -f $file_path && echo ✅ || echo ❌)"
    done
  exit
fi

if [ "$1" = 'toggle' ]; then
  file_path=`get_file_path $2`
  if printf '%s\0' "${states[@]}" | grep -Fxqz -- "$2"; then
    if [[ -f $file_path ]]; then
      rm $file_path
      command="$on_disabled_commands[$2]"
    else
      touch $file_path
      command="$on_enabled_commands[$2]"
    fi
    if [[ ! -z "$command" && "$3" != 'ignore-event' ]]; then
      { zsh -c "__custom_state=\"$2\"; source ~/.zshrc; eval \" $command\" > /dev/null 2>&1;" } &
    fi
    # kill BitBar
    ps -ef | grep "BitBar.app" | awk '{print $2}' | xargs kill 2> /dev/null
    # restart BitBar
    open -a /Applications/BitBar.app
    exit
  fi
fi

echo " | font='Symbols Nerd Font' size=18"
echo "---"
for state in "${states[@]}"; do
  file_path=`get_file_path $state`
  content=$(test -z "$icons[$state]" && echo "___$state" || echo "$icons[$state] $state")

  echo -e "$content\\t$(test -f $file_path && echo ✅ || echo ❌) |\
   bash=\"$0\" param1=toggle param2=$state terminal=false $style"
  echo -e "$content\\t$(test -f $file_path && echo ✅ || echo ❌) |\
   bash=\"$0\" param1=toggle param2=$state param3=ignore-event alternate=true refresh=true terminal=false $style"
done
echo "Refresh | refresh=true $style"

