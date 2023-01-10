#!/bin/bash

pass=$(security find-generic-password -l "macos root password" -w | tr -d '\n')

echo "$pass"
