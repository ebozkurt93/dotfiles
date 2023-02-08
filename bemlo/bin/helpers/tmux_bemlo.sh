#!/bin/bash

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

fb=true
if [[ -z $(lsof -i:4000 -t) ]]; then
	fb=false
fi

gh=$(~/Documents/bitbar_plugins/github-prs.5m.sh count)

echo ":$(p $docker) :$(p $pg) :$(p $fb)  :$gh"
