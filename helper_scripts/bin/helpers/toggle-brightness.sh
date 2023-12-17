#!/bin/sh
#
b=/usr/local/bin/brightness

val=$($b -lv 2>/dev/null  | awk '/display/ && /brightness/ {print $NF}' | tail -n 1)

if [ "$(echo "$val < 0.01" | bc)" -eq 1 ]; then
  $b 0.50
else
  $b 0
fi
