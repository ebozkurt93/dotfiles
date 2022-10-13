#!/bin/bash

style="size=13"
states=("work" "meeting" "holiday")

function get_file_path {
  echo ~/Documents/bitbar_plugins/tmp/$1
}

if [ "$1" = 'toggle' ]; then
  file_path=`get_file_path $2`
  echo $file_path
  if printf '%s\0' "${states[@]}" | grep -Fxqz -- "$2"; then
      test -f $file_path && rm $file_path || touch $file_path

  # kill BitBar
  ps -ef | grep "BitBar.app" | awk '{print $2}' | xargs kill
  # restart BitBar
  open -a /Applications/BitBar.app
  fi
fi

echo "✅"
echo "---"
for state in "${states[@]}"; do
  file_path=`get_file_path $state`
  echo -e "$state\\t$(test -f $file_path && echo ✅ || echo ❌) |\
   bash=\"$0\" param1=toggle param2=$state terminal=false $style"
done
echo "Refresh | refresh=true $style"
