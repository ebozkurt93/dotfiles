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

pr_names=$(echo $content | jq -r '.[] | "\(.repository.name)#\(.number)"')
pr_titles=$(echo $content | jq -r '.[] | "\(.title)"')
authors=$(echo $content | jq -r '.[] | "\(.author.login)"')
comment_counts=$(echo $content | jq -r '.[] | "\(.commentsCount)"')
urls=$(echo $content | jq -r '.[] | "\(.url)"')

while read -r line; do pr_names+=("$line"); done <<<"$pr_names"
while read -r line; do pr_titles+=("$line"); done <<<"$pr_titles"
while read -r line; do authors+=("$line"); done <<<"$authors"
while read -r line; do comment_counts+=("$line"); done <<<"$comment_counts"
while read -r line; do urls+=("$line"); done <<<"$urls"

echo "PRs: $(echo $content | jq -r length)| dropdown=true $style"
echo "---"
if [ $length != 0 ]; then
	for q in "${!pr_names[@]}"; do
		if [[ $q = 0 ]]; then
			continue
		fi
		printf "%-30s %-50s %-20s %2s | href=${urls[$q]} $style\n" "${pr_names[$q]}" "${pr_titles[$q]}" "👤 ${authors[$q]}" "💬 ${comment_counts[$q]}"
	done
echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false $style"
echo "Refresh | refresh=true $style"