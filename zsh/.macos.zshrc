__sourced_states=()
function _load_custom_zsh_on_dir () {
	if [[ ! -z $__custom_state && -f $HOME/.$__custom_state.zshrc ]]; then
	  source $HOME/.$__custom_state.zshrc
	  __sourced_states+=($__custom_state)
	fi
	local states=($(~/Documents/bitbar_plugins/state-switcher.5m enabled-states))
	for state in "${states[@]}"; do
	  if [[ $state == 'personal' ]]; then
	    # this one is unique, always sourced it by default
	    continue
	  fi
	  if [[ -f $HOME/.$state.zshrc && ! " ${__sourced_states[*]} " =~ " ${state} " ]]; then
	    local __paths=($(~/Documents/bitbar_plugins/state-switcher.5m state-paths $state))
	    if $(~/Documents/bitbar_plugins/state-switcher.5m always-sourced-if-enabled $state); then
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

alias code='open -a /Applications/Visual\ Studio\ Code.app/'
alias tailscale='/Applications/Tailscale.app/Contents/MacOS/Tailscale'

alias ss='echo $__sourced_states'

local function __state_switcher_toggle() {
  local p=~/Documents/bitbar_plugins/state-switcher.5m
  local selected_state=$($p states-with-marks | sort | fzf \
    --bind 'ctrl-space:become(echo _{})+abort,alt-j:become(echo __{})+abort,alt-k:become(echo ___{})+abort'
  )
  selected_state=$(echo $selected_state | awk '{print $1}')

  test -z $selected_state && return
  if [[ $selected_state =~ ^___.* ]]; then
    selected_state="$(echo "$selected_state" | cut -c4-)"
    $p run_hook on_enabled $selected_state
    zle reset-prompt
    return
  elif [[ $selected_state =~ ^__.* ]]; then
    selected_state="$(echo "$selected_state" | cut -c3-)"
    $p run_hook on_disabled $selected_state
    zle reset-prompt
    return
  fi

  if [[ $selected_state =~ ^_.* ]]; then
    selected_state="$(echo "$selected_state" | cut -c2-)"
    local suffix="ignore-event"
  fi
  $p toggle $selected_state $suffix
  zle reset-prompt
}
zle -N __state_switcher_toggle
bindkey "^[s" __state_switcher_toggle

alias cs="colima status > /dev/null 2>&1 && colima stop || colima start"

alias hsr='pgrep Hammerspoon | xargs kill; open -a /Applications/Hammerspoon.app'

function __find_repos {
  p=($(~/Documents/bitbar_plugins/state-switcher.5m enabled-states-paths) ~/bin)
  selected_dir="$(cat <(echo ~/dotfiles) \
    <(test ${#p[@]} -ne 0 && find ${p[@]} -maxdepth 1 -type d 2>/dev/null) \
    | sort | uniq | fzf --preview 'cd {}; tree -L 3 --filelimit 100 --dirsfirst \
      -C --noreport' --preview-window right --bind \
      'ctrl-p:change-preview-window(up|hidden|right),ctrl-n:become(echo \*{})+abort')"

  test -z "$selected_dir" && return
  if [[ "${selected_dir:0:1}" == "*" ]]; then
    selected_dir="${selected_dir:1}"
    openNvim=true
  fi

  cd "$selected_dir"
  zle reset-prompt
  if [[ -n $openNvim ]]; then
    nvim
  fi
}
zle -N __find_repos
bindkey "^f" __find_repos

function __open_pr {
  local p="$(~/Documents/bitbar_plugins/github-prs.5m.sh fzf)"
  local content="$(cat <(test ${#p[@]} -ne 0 && echo $p))"

  if [[ $1 == 'cmd' ]]; then
    echo "$content"
    return
  fi

  if [[ $1 == 'open' ]]; then
    shift
    for pr in "$@"; do
      echo "$pr" | awk '{print $NF}' | xargs open
    done
    return
  fi

  local _gh_pr_script=~/Documents/bitbar_plugins/github-prs.5m.sh
  local selected_output="$(
    cat <(test ${#p[@]} -ne 0 && echo $p) | fzf --multi --expect=enter \
      --bind "ctrl-f:reload($_gh_pr_script fzf)" \
      --bind "ctrl-e:reload($_gh_pr_script fzf | grep $GH_USERNAME || true)" \
      --bind "alt-f:reload($_gh_pr_script fzf | grep -v app/dependabot || true)" \
      --bind "ctrl-p:execute((echo {+} | tr ' ' '\n' | awk '{print \$NF}' | xargs open) &)+deselect-all" \
      --border=top --border-label=" GitHub PRs "
  )"

  local key selected
  key=$(echo "$selected_output" | sed -n 1p)
  selected=$(echo "$selected_output" | sed -n '2,$p')

  [[ -z "$selected" ]] && return

  if [[ "$key" == "enter" ]]; then
    echo "$selected" | awk '{print $NF}' | xargs open
    zle reset-prompt 2>/dev/null
  fi
}

zle -N __open_pr
bindkey "^[g" __open_pr 

function __bt_device_toggle() {
  if [[ "$(blueutil --power)" == "0" ]]; then
    echo 'bluetooth off'
    zle send-break
    return
  fi
  local c=$(blueutil --paired --format json | jq -r \
    '.[] | .name + " " + (.connected|tostring|sub("true"; "✅")|sub("false"; "❌")) + " " + .address')
  local selection=$(echo "$c" | sort | fzf --bind 'ctrl-p:become(echo _{})+abort')
  [[ -z $selection ]] && return
  address=$(echo $selection | awk '{print $NF}')
  if [[ $selection =~ ^_.* ]]; then
    blueutil --disconnect $address --wait-disconnect $address
    blueutil --connect $address --wait-connect $address
  elif [[ "$(blueutil --is-connected $address)" == '1' ]]; then
    blueutil --disconnect $address --wait-disconnect $address
  else
    blueutil --connect $address --wait-connect $address
  fi
  zle send-break
}

zle -N __bt_device_toggle
bindkey '^Xb' __bt_device_toggle

function wp_change() {
  local wp_file=$(~/bin/helpers/set_wallpaper.sh wp-path)
  local selection=$(~/bin/helpers/set_wallpaper.sh find | fzf --preview 'viu -b {}')
  [[ -z $selection ]] && return
  echo -e "$selection\n$(cat $wp_file)" > $wp_file
  ~/bin/helpers/set_wallpaper.sh
}

function __open_folder() {
  open .
}

zle -N __open_folder
bindkey "^[o" __open_folder

function __reload_ghostty_config {
  # native perform-action call -- no focus steal, unlike System Events keystroke sim
  osascript -e 'tell application "Ghostty" to perform action "reload_config" on (focused terminal of (selected tab of front window))' > /dev/null
}

_load_custom_zsh_on_dir
