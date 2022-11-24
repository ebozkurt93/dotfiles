#!/bin/bash

~/Documents/bitbar_plugins/helpers/check_work_hours.sh && true || exit

function p {
	[ $1 == true ] && echo '✓' || echo '✗'
}

docker=true
if ! docker info > /dev/null 2>&1; then
	docker=false
fi

pg=true
if [[ -z $(lsof -i:5432 -t) ]]; then
	pg=false
fi

gh=$(~/Documents/bitbar_plugins/github-prs.5m.sh count)

echo ":$(p $docker) :$(p $pg)  :$gh"
