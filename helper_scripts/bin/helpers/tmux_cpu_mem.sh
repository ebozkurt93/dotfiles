# ps -A -o %cpu,%mem | awk '{ cpu += $1; mem += $2} END {print "CPU: "cpu"% MEM: "mem"%"}'

cpu=$(top -l 2 -s 0 | grep -E "^CPU" | tail -1 | awk '{ printf "%.1f", $3 + $5 }')
mem=$(ps -A -o %mem | awk '{ mem += $1} END {print mem}')
echo CPU: $cpu% MEM: $mem%
