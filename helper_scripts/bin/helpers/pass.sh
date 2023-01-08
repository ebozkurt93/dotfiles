#!/bin/bash

pass=$(security find-generic-password -l "macos root password" -a root -w |tr -d '\n')

echo "$pass"
