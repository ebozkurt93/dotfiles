source $HOME/.personal.zshrc

function _load_custom_zsh_on_dir () {
	if [[ -f $HOME/.bemlo.zshrc && ! -v ___is_bemlo_sourced && $PWD/ = $HOME/bemlo/* ]]; then
		source $HOME/.bemlo.zshrc
		___is_bemlo_sourced=true
	fi
}

function chpwd() {
    _load_custom_zsh_on_dir
}

_load_custom_zsh_on_dir

# source /Users/erdembozkurt/.docker/init-zsh.sh || true # Added by Docker Desktop
