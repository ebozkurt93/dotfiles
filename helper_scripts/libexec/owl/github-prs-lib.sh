#!/usr/bin/env bash
# Shared by the owl pull request checks (reviews-waiting, my-approved-prs, my-stale-prs,
# team-prs-optional-review, location-management-prs), sourced from $HOME/libexec/owl/github-prs-lib.sh.
#
# Source it, then pipe the check's items through
# `annotate "<tags>"`; each item keeps its fields and gets the chosen tags appended to its detail.
#
# Titles of the form "repo: title" become "repo#12: title", so a "blocked on #12" can be found in the list.
#
#   stack      " · stack 2/5" (position/size, only when the pull request is part of a stack)
#   blocked    " · blocked on #34 (its title)" (lowest open pull request below it that is not approved)
#   mergefirst " · merge #34 first" (lowest open pull request below it, approved or not)
#   ci         " · CI failing"
#   conflicts  " · merge conflicts"
#   threads    " · 3 unresolved threads"
#
# Items are the check's {items: [...]} object or a bare list; each needs a pull request link in
# `id` or `url`. Anything that fails to resolve is left unannotated rather than failing the check.

# One request per repository (all pages), fetched in parallel, with everything the tags need for every open
# pull request in it. The stack and blocking logic then runs here in jq, with no per-item requests.
_pr_repo_data() { # repo tags -> JSON {default, prs: [{number, title, base, head, decision, conflicts, ci, threads}]}
  local tags=" $2 " extra=""
  [[ $tags == *" conflicts "* ]] && extra+=" mergeable"
  [[ $tags == *" threads "* ]] && extra+=" reviewThreads(first: 100) { nodes { isResolved } }"
  [[ $tags == *" ci "* ]] && extra+=" commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }"
  gh api graphql --paginate -f query='query($o: String!, $n: String!, $endCursor: String) { repository(owner: $o, name: $n) {
    defaultBranchRef { name }
    pullRequests(states: OPEN, first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { number title baseRefName headRefName reviewDecision'"$extra"' } } } }' \
    -f o="${1%%/*}" -f n="${1##*/}" \
    --jq '.data.repository | {default: .defaultBranchRef.name, prs: [.pullRequests.nodes[] | {
      number, title, base: .baseRefName, head: .headRefName, decision: (.reviewDecision // "NONE"),
      conflicts: (.mergeable == "CONFLICTING"),
      ci: (.commits.nodes[0].commit.statusCheckRollup.state // ""),
      threads: ([(.reviewThreads.nodes // [])[] | select(.isResolved | not)] | length)}]}' |
    jq -s '{default: .[0].default, prs: (map(.prs) | add)}'
}

# Adds the tags to each item's detail, and the pull request number to its title ("repo: title" becomes "repo#12: title"). $repos is {"owner/name": _pr_repo_data}; an item whose repository or
# pull request is not in it is left as it is.
_PR_ANNOTATE='
  def short: sub("^[a-z]+(\\([^)]*\\))?!?: "; "") | if length > 40 then .[:39] + "…" else . end | if . == "" then "" else " (" + . + ")" end;
  def down($prs; $cur; $acc): if ($acc | length) >= 9 then $acc
    else (first($prs[] | select(.head == $cur)) // null) as $p
      | if $p == null then $acc else down($prs; $p.base; $acc + [$p]) end end;
  def up($prs; $cur; $size): if $size >= 20 then $size
    else (first($prs[] | select(.base == $cur)) // null) as $p
      | if $p == null then $size else up($prs; $p.head; $size + 1) end end;
  def has($t): $tags | contains(" " + $t + " ");
  def extra($r; $pr):
    ((if $pr.base != $r.default then down($r.prs; $pr.base; []) else [] end)) as $below
    | (1 + ($below | length)) as $pos
    | up($r.prs; $pr.head; $pos) as $size
    | ($below | map(select(.decision != "APPROVED")) | last) as $blocker
    | ($below | last) as $lowest
    | (if has("stack") and $size > 1 then " · stack \($pos)/\($size)" else "" end)
      + (if has("blocked") and $blocker != null then " · blocked on #\($blocker.number)\($blocker.title | short)" else "" end)
      + (if has("mergefirst") and $lowest != null then " · merge #\($lowest.number) first" else "" end)
      + (if has("ci") and ($pr.ci == "FAILURE" or $pr.ci == "ERROR") then " · CI failing" else "" end)
      + (if has("conflicts") and $pr.conflicts then " · merge conflicts" else "" end)
      + (if has("threads") and $pr.threads > 0 then " · \($pr.threads) unresolved thread\(if $pr.threads == 1 then "" else "s" end)" else "" end);
  map(
    (try ((.id // .url // "") | capture("^https://github.com/(?<repo>[^/]+/[^/]+)/pull/(?<num>[0-9]+)")) catch null) as $m
    | ($repos[$m.repo // ""] // null) as $r
    | (if $r == null then null else first($r.prs[] | select(.number == ($m.num | tonumber))) // null end) as $pr
    | .detail = ((.detail // "") + (if $pr == null then "" else extra($r; $pr) end))
    | if $m == null then . else ($m.repo | split("/")[1]) as $name
      | if (.title // "") | startswith($name + ": ") then .title = $name + "#" + $m.num + ": " + (.title | ltrimstr($name + ": ")) else . end end)
'

# Gives each item a `detail_parts` list for owl to color: the detail split on " · ", every piece with a tone
# (alert/warn/ok/info/accent/faint) chosen by what it says. The plain `detail` is left as it is.
_PR_PAINT='
  def tone: if . == "CI failing" or . == "merge conflicts" or startswith("changes requested by") then "alert"
    elif startswith("blocked on ") or (startswith("merge #") and endswith(" first")) or test("unresolved threads?$") then "warn"
    elif . == "approved" then "ok"
    elif startswith("new commits") then "accent"
    elif startswith("stack ") then "info"
    elif test("^last (activity|updated) [0-9]+ days? ago$") and ((capture("(?<n>[0-9]+)").n | tonumber) >= 7) then "warn"
    else "faint" end;
  def piece($first): . as $s
    | if test("^\\+[0-9]+/-[0-9]+(, .*)?$") then
        capture("^\\+(?<a>[0-9]+)/-(?<d>[0-9]+)(?<r>, .*)?$") as $m
        | [{text: ("+" + $m.a), tone: "ok"}, {text: "/", tone: "faint"}, {text: ("-" + $m.d), tone: "alert"}]
          + (if ($m.r // "") != "" then [{text: $m.r, tone: "faint"}] else [] end)
      elif $first and test("^[A-Za-z0-9][A-Za-z0-9-]*$") and tone == "faint" then [{text: $s}]
      else [{text: $s, tone: tone}] end;
  def parts: split(" · ") | to_entries | map(.key as $i | (if $i > 0 then [{text: " · ", tone: "faint"}] else [] end) + (.value | piece($i == 0))) | add;
  map(if (.detail // "") != "" then . + {detail_parts: (.detail | parts)} else . end)
'

annotate() { # tags, items on stdin -> items on stdout
  local tags=$1 input tmp repo repos='{}'
  input=$(cat)
  tmp=$(mktemp -d) || return 1
  while IFS= read -r repo; do
    { _pr_repo_data "$repo" "$tags" >"$tmp/${repo//\//__}.json" 2>/dev/null || rm -f "$tmp/${repo//\//__}.json"; } &
  done < <(jq -r 'if type == "array" then . else .items end | .[] | (.id // .url // "")
    | capture("^https://github.com/(?<r>[^/]+/[^/]+)/pull/[0-9]+").r' <<<"$input" 2>/dev/null | sort -u)
  wait
  for f in "$tmp"/*.json; do
    [ -e "$f" ] || continue
    repo=$(basename "$f" .json); repo=${repo//__//}
    repos=$(jq -c --arg r "$repo" --slurpfile d "$f" '. + {($r): $d[0]}' <<<"$repos")
  done
  rm -rf "$tmp"
  local out
  out=$(jq -c 'if type == "array" then . else .items end' <<<"$input" | jq -c --arg tags " $tags " --argjson repos "$repos" "$_PR_ANNOTATE")
  out=$(jq -c "$_PR_PAINT" <<<"$out")
  if [ "$(jq -r type <<<"$input")" = array ]; then jq . <<<"$out"; else jq '{items: .}' <<<"$out"; fi
}
