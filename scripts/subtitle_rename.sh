#!/bin/sh

# update path before usage
pt=''

if [[ ! -d "$pt" ]]; then
  echo "Invalid path"
  exit
fi
exit

files=$(find "$pt" -maxdepth 1 -type f -name "*.mp4")
for file in $files
do
  filename="$(basename $file .mp4)"
  echo "$filename"
  cp "$pt/Subs/$filename/2_English.srt" "$pt/$filename.srt"
done
