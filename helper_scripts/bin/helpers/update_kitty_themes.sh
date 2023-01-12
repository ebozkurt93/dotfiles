#!/bin/sh

find "$PWD" -name '*kitty_themes*' | grep -v $0 | xargs -n1 sh

