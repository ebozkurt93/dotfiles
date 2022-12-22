#!/bin/bash

source ~/.zprofile
~/Documents/bitbar_plugins/helpers/check_work_hours.sh && true || exit
# todo: read this from somewhere
organization=''

if [ "$1" = 'run' ]; then
  C=$(find $2 -type f -name "*.go"| wc -l)
  if ((C > 0)); then
    cd $2 && open -a /Applications/Visual\ Studio\ Code.app .
  else
    cd $2 && open -a /Applications/PyCharm.app .
  fi
  exit
fi

if [ "$1" = 'vscode' ]; then
  cd $2 && open -a /Applications/Visual\ Studio\ Code.app .
  exit
fi

if [ "$1" = 'open' ]; then
  open -a $2
  exit
fi

if [ "$1" = 'terminal' ]; then
  open -a /Applications/iTerm.app $2
  exit
fi

if [ "$1" = 'clone' ]; then
  cd ~/repositories && git clone git@github.com:$organization/$2.git
  $0 run $3
  exit
fi

if [ "$1" = 'clone-vscode' ]; then
  cd ~/repositories && git clone git@github.com:$organization/$2.git
  $0 vscode $3
  exit
fi

if [ "$1" = 'clone-exit' ]; then
  cd ~/repositories && git clone git@github.com:$organization/$2.git
  exit
fi

if [ "$1" = 'refetch-repos' ]; then
  gh repo list $organization --json name,isArchived -L 100 | jq -r '.[] | select(.isArchived == false) | .name' | sort > ~/Documents/bitbar_plugins/tmp/repos.txt
  exit
fi

if [ "$1" = 'start-pg-d' ]; then
  open /Applications/Docker.app
  open /Applications/Postgres.app
  exit
fi

if [ "$1" = 'kill-pg-d' ]; then
  { osascript -e 'quit app "Docker"'; } &
  { 
	  osascript -e 'quit app "Postgres"';
	  osascript -e 'quit app "postgresmenuhelper"';
	  pkill postgres;
  } &
  exit
fi

echo "repos| dropdown=true size=13"
echo "---"
echo "🐘🐳 | bash=\"$0\" param1=start-pg-d terminal=false size=13"
echo "🔪🐘🐳 | bash=\"$0\" param1=kill-pg-d terminal=false size=13"
echo "---"

cat ~/Documents/bitbar_plugins/tmp/repos.txt | while read line 
do
  sp=~/repositories/$line
  if [ -d ~/repositories/$line ]; then
    # sp=$(echo $line | sed -e 's/\(.*\/\)\(.*\)\(\/\)/\2/g')
    echo "$line | bash=\"$0\" param1=run param2=$sp terminal=false size=13"
    echo "--GitHub | href=\"https://github.com/$organization/$line\" color=#666666 size=13"
    echo "--Visual Studio Code | bash=\"$0\" param1=vscode param2=$sp terminal=false color=#666666 size=13"
    echo "$line | bash=\"$0\" alternate=true param1=terminal param2=$sp terminal=false size=13"
  else
    echo "$line | href=\"https://github.com/$organization/$line\" color=#666666 size=13"
	echo "--Clone | bash=\"$0\" param1=clone-exit param2=$line param3=$sp terminal=false size=13"
	echo "--Clone & Open In Visual Studio Code | bash=\"$0\" param1=clone-vscode param2=$line param3=$sp terminal=false size=13"
    echo "$line | bash=\"$0\" param1=clone param2=$line param3=$sp alternate=true terminal=false color=#666666 size=13"
  fi
done

# for d in ~/repositories/*/ ; do
#     sp=$(echo $d | sed -e 's/\(.*\/\)\(.*\)\(\/\)/\2/g')
#     echo "$sp | bash=\"$0\" param1=run param2=$d terminal=false size=13"
#     echo "$sp | bash=\"$0\" alternate=true param1=terminal param2=$d terminal=false size=13"
# done

echo "---"
echo "Docker | bash=\"$0\" param1=open param2=/Applications/Docker.app terminal=false size=13"
echo "Postgres | bash=\"$0\" param1=open param2=/Applications/Postgres.app terminal=false size=13"
echo "---"
echo "Refetch repos | bash=\"$0\" param1=refetch-repos refresh=true terminal=false size=13"
echo "Refresh | refresh=true size=13"
