#!/bin/bash

case $PWD/ in
  $HOME/bemlo/*/*) exit 0;;
  *) exit 1;;
esac
