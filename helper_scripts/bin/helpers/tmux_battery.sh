charging=$(pmset -g batt | tail -n 1 | awk -F ' ' 'gsub(";", "", $0) {print "BAT:", $3, $4}')
charging=$(echo $charging | sed -e 's/discharging//g' -e 's/charging//g' -e 's/charged/-/g' -e 's/finishing/-/g')
pwr_source=$(pmset -g batt | head -n 1 | cut -c 17- | sed "s/'//g" | xargs)

if [[ "$pwr_source" == 'AC Power' ]]; then
	pwr_source='󱐥'
else
	pwr_source=''
fi

pwr=$(pmset -g | grep lowpowermode | awk -F' ' '{ print$2 }')
if [[ $pwr == '1' ]]; then
	pwr='L'
else
	pwr=''
fi
echo $charging $pwr $pwr_source

