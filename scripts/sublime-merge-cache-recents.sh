# !/bin/sh

paths=(~/repositories ~/personal-repositories)

for p in ${paths[@]}; do
  cd "$p"
  for d in */ ; do
    if [[ $(git -C "$d" rev-parse 2>/dev/null; echo $?) = 0 ]]; then
      open -a "/Applications/Sublime Merge.app" "$d"
    fi
  done
done
