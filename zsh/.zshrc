source $HOME/.personal.zshrc

__sourced_states=()
function _load_custom_zsh_on_dir () {
	if [[ ! -z $__custom_state && -f $HOME/.$__custom_state.zshrc ]]; then
	  source $HOME/.$__custom_state.zshrc
	  __sourced_states+=($__custom_state)
	fi
	local states=($(~/Documents/bitbar_plugins/state-switcher.5m.sh enabled-states))
	for state in "${states[@]}"; do
	  if [[ $state == 'personal' ]]; then
	    # this one is unique, always sourced it by default
	    continue
	  fi
	  if [[ -f $HOME/.$state.zshrc && ! " ${__sourced_states[*]} " =~ " ${state} " ]]; then
	    local __paths=($(~/Documents/bitbar_plugins/state-switcher.5m.sh state-paths $state))
	    if $(~/Documents/bitbar_plugins/state-switcher.5m.sh always-sourced-if-enabled $state); then
	        source $HOME/.$state.zshrc
	        __sourced_states+=($state)
	        continue
	    fi
	    for __path in ${__paths[@]}; do
	      if [[ $PWD/ = $__path/* ]]; then
	        source $HOME/.$state.zshrc
	        __sourced_states+=($state)
	        break
	      fi
	    done
	  fi
	done
}

function chpwd() {
    _load_custom_zsh_on_dir
}

_load_custom_zsh_on_dir

# source /Users/erdembozkurt/.docker/init-zsh.sh || true # Added by Docker Desktop
