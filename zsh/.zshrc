source $HOME/.personal.zshrc

function _load_custom_zsh_on_dir () {
	if [[ ! -v ___is_alva_sourced && $PWD/ = $HOME/repositories/* ]]; then
		source $HOME/.alva.zshrc
		___is_alva_sourced=true
	fi
	if [[ ! -v ___is_bemlo_sourced && $PWD/ = $HOME/bemlo/* ]]; then
		source $HOME/.bemlo.zshrc
		___is_bemlo_sourced=true
	fi
}

function chpwd() {
    _load_custom_zsh_on_dir
}

_load_custom_zsh_on_dir
