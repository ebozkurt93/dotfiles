#!/bin/bash

# bitbar cannot access jq for some reason
JQ=/opt/homebrew/bin/jq
GH=/opt/homebrew/bin/gh
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
		`echo $GH search prs "$q" --json "$json_format" | xargs` >> "$prs_file"
	done
	exit
fi


content=$(cat $prs_file | $JQ -s 'add' | $JQ -r unique_by\(.id\) | $JQ -r sort_by\(.updatedAt\))
length="$(echo $content | $JQ -r length)"
echo "PRs: $(echo $content | $JQ -r length)| dropdown=true $style"
echo "---"
results=$(echo $content | $JQ -r '.[] | "\(.repository.name)#\(.number)\t\(.title)\t👤 \(.author.login)\t💬 \(.commentsCount)"')
urls=$(echo $content | $JQ -r '.[] | "\(.url)"')
while read -r line; do results+=("$line"); done <<<"$results"
while read -r line; do urls+=("$line"); done <<<"$urls"

if [ $length != 0 ]; then
	for q in "${!results[@]}"; do
		if [[ $q = 0 ]]; then
			continue
		fi
		echo "${results[$q]} | href=${urls[$q]} $style"
	done
echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false size=13"
echo "Refresh | refresh=true $style"