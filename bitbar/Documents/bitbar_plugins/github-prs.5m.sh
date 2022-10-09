#!/bin/bash

source ~/.zprofile
~/Documents/bitbar_plugins/helpers/check_work_hours.sh && true || exit

style="size=13"

queries=(
"org:alvalabs is:open archived:false author:@me"
"org:alvalabs is:open archived:false commenter:@me"
"org:alvalabs is:open archived:false review-requested:@me"
)
json_format="assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url"

prs_file=~/Documents/bitbar_plugins/tmp/prs.txt

if [ "$1" = 'refetch-prs' ]; then
	rm $prs_file
	# adding empty array since no results makes jq fail
	echo '[]' >> "$prs_file"
	for q in "${queries[@]}"; do
		`echo gh search prs "$q" --json "$json_format" | xargs` >> "$prs_file"
	done
	exit
fi


content=$(cat $prs_file | jq -s 'add' | jq -r unique_by\(.id\) | jq -r sort_by\(.updatedAt\))
length="$(echo $content | jq -r length)"
results=$(echo $content | jq -r '.[] | "\(.repository.name)#\(.number)\t\(.title)\t👤 \(.author.login)\t💬 \(.commentsCount)"')
urls=$(echo $content | jq -r '.[] | "\(.url)"')
while read -r line; do results+=("$line"); done <<<"$results"
while read -r line; do urls+=("$line"); done <<<"$urls"

echo "PRs: $(echo $content | jq -r length)| dropdown=true $style"
echo "---"
if [ $length != 0 ]; then
	for q in "${!results[@]}"; do
		if [[ $q = 0 ]]; then
			continue
		fi
		echo "${results[$q]} | href=${urls[$q]} $style"
	done
echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false $style"
echo "Refresh | refresh=true $style"