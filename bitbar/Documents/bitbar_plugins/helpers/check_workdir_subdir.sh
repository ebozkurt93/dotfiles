#!/bin/bash

case $PWD/ in
  $HOME/repositories/*/*) exit 0;;
  $HOME/bemlo/*/*) exit 0;;
  *) exit 1;;
esac
