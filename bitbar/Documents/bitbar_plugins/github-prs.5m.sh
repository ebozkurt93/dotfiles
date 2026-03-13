#!/bin/bash

if [[ "$1" != "fzf" && "$1" != "count" ]]; then
	source ~/.zprofile
	source ~/.zshrc >/dev/null 2>&1
	PATH="${PATH}:${HOME}/.nix-profile/bin"
	~/Documents/bitbar_plugins/state-switcher.5m is-state-enabled instabee || exit
else
	PATH="${PATH}:${HOME}/.nix-profile/bin"
fi

style="size=13"

OLDIFS="$IFS"
IFS=$'\n'
queries=()
while read line; do
	# support for very basic commenting
	if [[ "$line" == //* || -z "$line" ]]; then
		continue
	fi
	queries=("${queries[@]}" "$line")
done <~/Documents/bitbar_plugins/tmp/queries.txt
IFS="$OLDIFS"

search_json_format="assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url"
pr_json_format="additions,assignees,author,baseRefName,body,changedFiles,closed,closedAt,comments,commits,createdAt,deletions,files,headRefName,headRepository,headRepositoryOwner,id,isCrossRepository,isDraft,labels,latestReviews,maintainerCanModify,mergeCommit,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,potentialMergeCommit,projectCards,reactionGroups,reviewDecision,reviewRequests,reviews,state,statusCheckRollup,title,updatedAt,url"
# pr_json_format="additions,assignees,author,baseRefName,body,changedFiles,closed,closedAt,comments,commits,createdAt,deletions,files,headRefName,headRepository,headRepositoryOwner,id,isCrossRepository,isDraft,labels,latestReviews,maintainerCanModify,mergeCommit,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,potentialMergeCommit,projectCards,reactionGroups,reviewDecision,reviewRequests,reviews,state,statusCheckRollup,title,updatedAt,url"

temp_prs_file=~/Documents/bitbar_plugins/tmp/prs_$(date +%Y%m%d%H%M%S).txt
prs_file=~/Documents/bitbar_plugins/tmp/prs.txt

if [ "$1" = 'refetch-prs' ]; then
	all_pr_ids=""
	for q in "${queries[@]}"; do
		prs=$($(echo gh search prs $q --json "$search_json_format" | xargs))
		pr_ids=$(echo "$prs" | jq -r '.[] | "\(.url)"' | xargs)
		all_pr_ids+=" $pr_ids"
	done
	all_pr_ids=$(echo "$all_pr_ids" | tr ' ' '\n' | sort | uniq | xargs)

	read -a all_pr_ids <<<$all_pr_ids
	# adding empty array since no results makes jq fail
	echo '[]' >>"$temp_prs_file"
	for url in "${all_pr_ids[@]}"; do
		pr=$($(echo gh pr view "$url" --json "$pr_json_format" | xargs))
		echo "[$pr]" >>$temp_prs_file
	done

	mv $temp_prs_file $prs_file
	exit
fi

content=$(jq -s 'add | unique_by(.id) | sort_by(.updatedAt)' "$prs_file")

if [ "$1" = 'count' ]; then
	length="$(echo "$content" | jq 'length')"
	non_dependabot_length="$(echo "$content" | jq '[.[] | select(.author.login != "app/dependabot")] | length')"
	echo "$length ($non_dependabot_length)"
	exit
fi

if [ "$1" = 'fzf' ]; then
	echo "$content" | jq -r 'reverse[] |
    [
      ((.headRepository.name + "#" + (.number | tostring)) | .[0:30] + if length > 30 then "..." else "" end | .[0:30]),
      (.title | .[0:80] + if length > 80 then "..." else "" end | .[0:80]),
      (.author.login | .[0:20] + if length > 20 then "..." else "" end | .[0:20]),
      .createdAt[0:22],
      .updatedAt[0:22],
      (if .isDraft then "Draft" else "" end),
      .url
    ] | @tsv' | awk -F'\t' '{printf "%-30s %-80s %-20s %-25s %-25s %-7s %-60s\n", $1, $2, $3, $4, $5, $6, $7}'
	exit
fi

length="$(echo "$content" | jq 'length')"
non_dependabot_length="$(echo "$content" | jq '[.[] | select(.author.login != "app/dependabot")] | length')"

pr_names=$(echo $content | jq -r '.[] | "\(.headRepository.name)#\(.number)"')
pr_titles=$(echo $content | jq -r '.[] | "\(.title)"')
authors=$(echo $content | jq -r '.[] | "\(.author.login)"')
comment_counts=$(echo $content | jq -r '.[] | "\(.comments)"' | jq length)
additions=$(echo $content | jq -r '.[] | "\(.additions)"')
deletions=$(echo $content | jq -r '.[] | "\(.deletions)"')
is_draft=$(echo $content | jq -r '.[] | "\(.isDraft)"' | sed -e 's/true/Draft/g' -e 's/false//g')
review_decision=$(echo $content | jq -r '.[] | "\(.reviewDecision)"' | sed -e 's/APPROVED/Approved/g' \
	-e 's/REVIEW_REQUIRED/Review required/g' -e 's/CHANGES_REQUESTED/Changes requested/g')
mergeable=$(echo $content | jq -r '.[] | "\(.mergeable)"' | sed -e '/MERGEABLE/!s/.*/Not mergeable/g' -e 's/MERGEABLE//g')
urls=$(echo $content | jq -r '.[] | "\(.url)"')

while read -r line; do pr_names+=("$line"); done <<<"$pr_names"
while read -r line; do pr_titles+=("$line"); done <<<"$pr_titles"
while read -r line; do authors+=("$line"); done <<<"$authors"
while read -r line; do comment_counts+=("$line"); done <<<"$comment_counts"
while read -r line; do additions+=("$line"); done <<<"$additions"
while read -r line; do deletions+=("$line"); done <<<"$deletions"
while read -r line; do is_draft+=("$line"); done <<<"$is_draft"
while read -r line; do review_decision+=("$line"); done <<<"$review_decision"
while read -r line; do mergeable+=("$line"); done <<<"$mergeable"
while read -r line; do urls+=("$line"); done <<<"$urls"

echo "PRs: $length ($non_dependabot_length)| dropdown=true $style"
echo "---"
if [ $length != 0 ]; then
	for q in "${!pr_names[@]}"; do
		if [[ $q = 0 ]]; then
			continue
		fi
		printf "%-30s %-70s %-20s %-2s %-7s %-52s | href=${urls[$q]} $style $([[ "${authors[$q]}" == "$GH_USERNAME" ]] && echo " color=teal ") \
    $([[ "${authors[$q]}" == "app/dependabot" ]] && echo " color=dimgray ") \n" "${pr_names[$q]}" "${pr_titles[$q]}" \
			"👤 ${authors[$q]}" "💬 ${comment_counts[$q]}" "📜+${additions[$q]}-${deletions[q]}" "${is_draft[q]} ${review_decision[q]} ${mergeable[q]}"
	done
	echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false $style"
echo "Refresh | refresh=true $style"
