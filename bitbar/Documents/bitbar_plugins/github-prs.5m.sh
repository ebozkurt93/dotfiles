#!/bin/bash

source ~/.zprofile
source ~/.zshrc > /dev/null 2>&1
PATH="${PATH}:${HOME}/.nix-profile/bin"
~/Documents/bitbar_plugins/state-switcher.5m is-state-enabled instabee || exit

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

temp_prs_file=~/Documents/bitbar_plugins/tmp/prs_$(date +%Y%m%d%H%M%S).txt
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
  # adding empty array since no results makes jq fail
  echo '[]' >> "$temp_prs_file"
  for url in "${all_pr_ids[@]}"; do
    pr=$(`echo gh pr view "$url" --json "$pr_json_format" | xargs`)
    echo "[$pr]" >> $temp_prs_file
  done

  mv $temp_prs_file $prs_file
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
review_decision=$(echo $content | jq -r '.[] | "\(.reviewDecision)"' | sed -e 's/APPROVED/Approved/g' \
  -e 's/REVIEW_REQUIRED/Review required/g' -e 's/CHANGES_REQUESTED/Changes requested/g')
mergeable=$(echo $content | jq -r '.[] | "\(.mergeable)"' | sed -e '/MERGEABLE/!s/.*/Not mergeable/g' -e 's/MERGEABLE//g')
urls=$(echo $content | jq -r '.[] | "\(.url)"')
created_at=$(echo $content | jq -r '.[] | "\(.createdAt)"')
updated_at=$(echo $content | jq -r '.[] | "\(.updatedAt)"')

while read -r line; do pr_names+=("$line"); done <<<"$pr_names"
while read -r line; do pr_titles+=("$line"); done <<<"$pr_titles"
while read -r line; do authors+=("$line"); done <<<"$authors"
while read -r line; do comment_counts+=("$line"); done <<<"$comment_counts"
while read -r line; do additions+=("$line"); done <<<"$additions"
while read -r line; do deletions+=("$line"); done <<<"$deletions"
while read -r line; do is_draft+=("$line"); done <<<"$is_draft"
while read -r line; do review_decision+=("$line"); done <<<"$review_decision"
while read -r line; do mergeable+=("$line"); done <<<"$mergeable"
while read -r line; do created_at+=("$line"); done <<<"$created_at"
while read -r line; do updated_at+=("$line"); done <<<"$updated_at"
while read -r line; do urls+=("$line"); done <<<"$urls"

if [ "$1" = 'fzf' ]; then
  for (( q=${#pr_names[@]}-1; q>0; q-- )); do
    # printf "%-30s %-80s %-20s %-25s %-25s %-60s\n" "${pr_names[$q]}" "${pr_titles[$q]}" "${authors[$q]}" "${created_at[$q]}" "${updated_at[$q]}" "${urls[$q]}"
    printf "%-30s %-80s %-20s %-25s %-25s %-60s\n" \
  "$(if [ ${#pr_names[$q]} -gt 30 ]; then echo "${pr_names[$q]:0:27}..."; else echo "${pr_names[$q]}"; fi)" \
  "$(if [ ${#pr_titles[$q]} -gt 80 ]; then echo "${pr_titles[$q]:0:77}..."; else echo "${pr_titles[$q]}"; fi)" \
  "$(if [ ${#authors[$q]} -gt 20 ]; then echo "${authors[$q]:0:17}..."; else echo "${authors[$q]}"; fi)" \
  "$(if [ ${#created_at[$q]} -gt 25 ]; then echo "${created_at[$q]:0:22}..."; else echo "${created_at[$q]}"; fi)" \
  "$(if [ ${#updated_at[$q]} -gt 25 ]; then echo "${updated_at[$q]:0:22}..."; else echo "${updated_at[$q]}"; fi)" \
  "${urls[$q]}"
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
    printf "%-30s %-70s %-20s %-2s %-7s %-52s | href=${urls[$q]} $style $( [[ "${authors[$q]}" == "$GH_USERNAME" ]] && echo " color=teal ") \
    $( [[ "${authors[$q]}" == "app/dependabot" ]] && echo " color=dimgray ") \n" "${pr_names[$q]}" "${pr_titles[$q]}" \
    "👤 ${authors[$q]}" "💬 ${comment_counts[$q]}" "📜+${additions[$q]}-${deletions[q]}" "${is_draft[q]} ${review_decision[q]} ${mergeable[q]}"
  done
  echo "---"
fi

echo "Refetch PRs | bash=\"$0\" param1=refetch-prs refresh=true terminal=false $style"
echo "Refresh | refresh=true $style"
