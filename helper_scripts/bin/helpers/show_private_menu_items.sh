#!/bin/sh
# Decides when calendar status(from raycast) and other similar menu items should be visible in menu bar
# Needs extra configuration on bartender 4 + raycast to be useful

if ! ~/Documents/bitbar_plugins/state-switcher.5m.py is-state-enabled meeting; then
  echo true
  exit 0
fi
exit -1
