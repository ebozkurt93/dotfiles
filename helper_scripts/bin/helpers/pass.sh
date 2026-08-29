#!/usr/bin/env bash

if [ "$(uname)" = "Darwin" ]; then
  pass=$(security find-generic-password -l "macos root password" -w | tr -d '\n')
else
  pass=$(secret-tool lookup purpose sudo-password | tr -d '\n')
fi

echo "$pass"
