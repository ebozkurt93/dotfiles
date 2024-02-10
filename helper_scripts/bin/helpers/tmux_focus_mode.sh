~/bin/helpers/get-focus-mode | cat | xargs echo \
	| sed -e 's/Do Not Disturb//g' -e 's/Personal//g' -e 's/Work/ /g'
