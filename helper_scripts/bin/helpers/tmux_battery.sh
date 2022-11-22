charging=$(pmset -g batt | tail -n 1 | awk -F ' ' 'gsub(";", "", $0) {print "BAT:", $3, $4}')
charging=$(echo $charging | sed -e 's/discharging/↓/g' -e 's/charging/↑/g' -e 's/charged/-/g')

pwr=$(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }')
if [[ $pwr == '1' ]]; then
	pwr='L'
else
	pwr=''
fi
echo $charging $pwr

