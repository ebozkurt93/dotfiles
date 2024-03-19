charging=$(pmset -g batt | awk -F ' ' 'gsub(";", "", $0) {print "BAT:", $3, $4}')
charging=$(echo $charging | sed -e 's/discharging//g' -e 's/charging//g' -e 's/charged/-/g' -e 's/finishing/-/g')
# not all these operations below are probably needed anymore, but keeping them anyway for now
pwr_source=$(pmset -g batt | cut -c 17- | sed "s/'//g" | xargs)

if [[ "$pwr_source" =~ ^"AC Power" ]]; then
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

