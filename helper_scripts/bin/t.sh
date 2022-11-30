#!/bin/bash
if [[ $TERM_PROGRAM != "tmux" ]]; then
	echo Tmux is not active, exiting...
	exit
fi
session_name=$(tmux display-message -p "#S")
if [[ $session_name != "alva" ]]; then
	echo Invalid session name $session_name, exiting...
	exit
fi
tmux new-window -c "$HOME/repositories/setup-scripts"
p1=$(tmux display-message -p "#{pane_id}")
tmux split-window -h -c "$HOME/repositories/apollo-federation-gateway"
p2=$(tmux display-message -p "#{pane_id}")
tmux split-window -v -p 66 -c "$HOME/repositories/alva-app"
p3=$(tmux display-message -p "#{pane_id}")
tmux split-window -v -p 50 -c "$HOME/repositories/admin"
p4=$(tmux display-message -p "#{pane_id}")

tmux send-keys -t $p1 './run_services.sh' C-m
sleep 7
tmux send-keys -t $p2 'fr' C-m
sleep 10
tmux send-keys -t $p3 'fr' C-m
tmux send-keys -t $p4 'fr' C-m
