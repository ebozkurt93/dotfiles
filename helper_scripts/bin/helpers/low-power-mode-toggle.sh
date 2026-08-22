if [ "$(uname)" = "Darwin" ]; then
  pass=$(~/bin/helpers/pass.sh)
  new_mode=$(( ($(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }') + 1) % 2 ))

  echo "$pass" | sudo -S pmset -a lowpowermode $new_mode
else
  current=$(powerprofilesctl get)
  if [ "$current" = "power-saver" ]; then
    powerprofilesctl set balanced
  else
    powerprofilesctl set power-saver
  fi
fi

