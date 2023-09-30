pass=$(~/bin/helpers/pass.sh)
new_mode=$(( ($(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }') + 1) % 2 ))

echo "$pass" | sudo -S pmset -a lowpowermode $new_mode

