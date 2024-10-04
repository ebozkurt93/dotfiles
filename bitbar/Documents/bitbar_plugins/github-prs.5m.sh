#!/bin/bash

PATH="${PATH}:${HOME}/.nix-profile/bin"
~/Documents/bitbar_plugins/state-switcher.5m.py is-state-enabled instabee || exit

style="size=13"

OLDIFS="$IFS"
IFS=$'\n'
queries=()
while read line
do
  # support for very basic commenting
  if [[ "$line" == //* || -z "$line" ]]; then
    continue
  fi
  queries=("${queries[@]}" "$line")
done < ~/Documents/bitbar_plugins/tmp/queries.txt
IFS="$OLDIFS"

search_json_format="assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url"
pr_json_format="additions,assignees,author,baseRefName,body,changedFiles,closed,closedAt,comments,commits,createdAt,deletions,files,headRefName,headRepository,headRepositoryOwner,id,isCrossRepository,isDraft,labels,latestReviews,maintainerCanModify,mergeCommit,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,potentialMergeCommit,projectCards,reactionGroups,reviewDecision,reviewRequests,reviews,state,statusCheckRollup,title,updatedAt,url"
# pr_json_format="additions,assignees,author,baseRefName,body,changedFiles,closed,closedAt,comments,commits,createdAt,deletions,files,headRefName,headRepository,headRepositoryOwner,id,isCrossRepository,isDraft,labels,latestReviews,maintainerCanModify,mergeCommit,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,potentialMergeCommit,projectCards,reactionGroups,reviewDecision,reviewRequests,reviews,state,statusCheckRollup,title,updatedAt,url"

prs_file=~/Documents/bitbar_plugins/tmp/prs.txt

if [ "$1" = 'refetch-prs' ]; then
  all_pr_ids=""
  for q in "${queries[@]}"; do
    prs=$(`echo gh search prs "$q" --json "$search_json_format" | xargs`)
    pr_ids=$(echo "$prs" | jq -r '.[] | "\(.url)"' | xargs)
    all_pr_ids+=" $pr_ids"
  done
  all_pr_ids=$(echo "$all_pr_ids" | tr ' ' '\n' | sort | uniq | xargs)

  read -a all_pr_ids <<< $all_pr_ids
  rm $prs_file
  # adding empty array since no results makes jq fail
  echo '[]' >> "$prs_file"
  for url in "${all_pr_ids[@]}"; do
    pr=$(`echo gh pr view "$url" --json "$pr_json_format" | xargs`)
    echo "[$pr]" >> $prs_file
  done

  exit
fi


content=$(cat $prs_file | jq -s 'add' | jq -r unique_by\(.id\) | jq -r sort_by\(.updatedAt\))
length="$(echo $content | jq -r length)"

if [ "$1" = 'count' ]; then
  echo $length
  exit
fi

pr_names=$(echo $content | jq -r '.[] | "\(.headRepository.name)#\(.number)"')
pr_titles=$(echo $content | jq -r '.[] | "\(.title)"')
authors=$(echo $content | jq -r '.[] | "\(.author.login)"')
comment_counts=$(echo $content | jq -r '.[] | "\(.comments)"' | jq length)
additions=$(echo $content | jq -r '.[] | "\(.additions)"')
deletions=$(echo $content | jq -r '.[] | "\(.deletions)"')
is_draft=$(echo $content | jq -r '.[] | "\(.isDraft)"' | sed -e 's/true/Draft/g' -e 's/false//g')
review_decision=$(echo $content | jq -r '.[] | "\(.reviewDecision)"' | sed -e 's/APPROVED/Approved/g' -e 's/REVIEW_REQUIRED/Review required/g')
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

if [ "$1" = 'fzf' ]; then
  for q in "${!pr_names[@]}"; do
    if [[ $q = 0 ]]; then
      continue
    fi
    printf "%-30s %-80s %-20s %-50s\n" "${pr_names[$q]}" "${pr_titles[$q]}" "${authors[$q]}" "${urls[$q]}"
    done
  exit
fi


echo "PRs: $(echo $content | jq -r length)| dropdown=true $style"
echo "---"
if [ $length != 0 ]; then
  for q in "${!pr_names[@]}"; do
    if [[ $q = 0 ]]; then
      continue
    fi
    printf "%-30s %-70s %-20s %-2s %-7s %-52s | href=${urls[$q]} $style $( [[ "${authors[$q]}" == "$GH_USERNAME" ]] && echo " color=blue ") \
    $( [[ "${authors[$q]}" == "app/dependabot" ]] && echo " color=#999999 ") \n" "${pr_names[$q]}" "${pr_titles[$q]}" \
    "👤 ${authors[$q]}" "💬 ${comment_counts[$q]}" "📜+${additions[$q]}-${deletions[q]}" "${is_draft[q]} ${review_decision[q]} ${mergeable[q]}"
  done
  echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false $style"
echo "Refresh | refresh=true $style"
