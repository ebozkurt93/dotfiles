#!/bin/zsh

style="size=13"
states=("meeting" "holiday" "personal" "bemlo")
typeset -A icons 
icons=(
	['meeting']='🤝'
	['holiday']='🌞'
	['personal']='🧔'
	['bemlo']='🚀'
)

typeset -A paths 
# these paths can be multiple per state, separate with spaces
paths=(
      ['personal']="$HOME/personal-repositories"
      ['bemlo']="$HOME/bemlo"
)

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

