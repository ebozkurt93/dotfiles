pass=$(~/bin/helpers/pass.sh)
items=$(echo "$pass" | sudo -S /usr/local/vanta/vanta-cli schedule | tail -n +1)
ts=$(date +%Y%m%d%H%M%S)
echo "$items" > ~/Documents/vanta-backup/$ts.json

