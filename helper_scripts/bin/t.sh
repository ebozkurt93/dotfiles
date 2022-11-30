#!/bin/bash

{ 
	sleep 1
	tmux new-window -c "$HOME/repositories/setup-scripts";
	tmux send-keys './run_services.sh' C-m
} &
{ 
	sleep 8
	tmux split-window -h -c "$HOME/repositories/apollo-federation-gateway"
	sleep 3
	tmux send-keys 'fr' C-m
} &
{ 
	sleep 14
	tmux split-window -v -p 66 -c "$HOME/repositories/alva-app"
	sleep 3
	tmux send-keys 'fr' C-m
} &
{ 
	sleep 19
	tmux split-window -v -p 50 -c "$HOME/repositories/admin"
	sleep 3
	tmux send-keys 'fr' C-m
} &
