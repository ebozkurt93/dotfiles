#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
	exit 0
fi

~/bin/helpers/get-focus-mode | cat | xargs echo \
	| sed -e 's/Do Not Disturb//g' -e 's/Personal//g' -e 's/Work/ /g'
