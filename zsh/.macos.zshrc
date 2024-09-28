__sourced_states=()
function _load_custom_zsh_on_dir () {
	if [[ ! -z $__custom_state && -f $HOME/.$__custom_state.zshrc ]]; then
	  source $HOME/.$__custom_state.zshrc
	  __sourced_states+=($__custom_state)
	fi
	local states=($(~/Documents/bitbar_plugins/state-switcher.5m.py enabled-states))
	for state in "${states[@]}"; do
	  if [[ $state == 'personal' ]]; then
	    # this one is unique, always sourced it by default
	    continue
	  fi
	  if [[ -f $HOME/.$state.zshrc && ! " ${__sourced_states[*]} " =~ " ${state} " ]]; then
	    local __paths=($(~/Documents/bitbar_plugins/state-switcher.5m.py state-paths $state))
	    if $(~/Documents/bitbar_plugins/state-switcher.5m.py always-sourced-if-enabled $state); then
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

if is_macos; then
  function chpwd() {
    _load_custom_zsh_on_dir
  }

  _load_custom_zsh_on_dir
fi

alias code='open -a /Applications/Visual\ Studio\ Code.app/'

# asdf
. "$HOME/.nix-profile/share/asdf-vm/asdf.sh"
. ~/.asdf/plugins/java/set-java-home.zsh
export PATH=$PATH:~/.asdf/installs/golang/1.19.1/packages/bin
# zsh-autosuggestions
source ~/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept

alias d-stop="docker system info > /dev/null 2>&1 && ps ax|grep -i docker|egrep -iv 'grep|com.docker.vmnetd'|awk '{print \$1}'|xargs kill"
alias d-start="open -a /Applications/Docker.app"
alias d-restart="d-stop; sleep 1; d-start && while ! docker system info > /dev/null 2>&1; do sleep 1; done"
alias ds="d-stop || d-start"
alias ss='echo $__sourced_states'

function nvim_remote_exec {
  local pc="$(nproc)"
  find /var/folders -name '*nvim*' 2>/dev/null | tail -n +2 | xargs -P $pc -I {} nvim --server {} --remote-send "$1"
}

# given a file pattern and commands, this function will rerun commands whenever files change
function res {
  find . -name "$1" | entr ${@:2}
}

function resr {
  find . -name "$1" | entr -s ${@:2}
}

alias dev-rust='res "*.rs" -r cargo run'
alias dev-go='res "*.go" -r go run .'

local function __state_switcher_toggle() {
  local p=~/Documents/bitbar_plugins/state-switcher.5m.py
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

alias cat='bat --paging=never'
alias lg='lazygit'

alias hsr='pgrep Hammerspoon | xargs kill; open -a /Applications/Hammerspoon.app'

function __find_repos {
  p=($(~/Documents/bitbar_plugins/state-switcher.5m.py enabled-states-paths) ~/bin)
  selected_dir="$(cat <(echo ~/dotfiles) \
    <(test ${#p[@]} -ne 0 && find ${p[@]} -maxdepth 1 -type d 2>/dev/null) \
    | sort | uniq | fzf --preview 'cd {}; tree -L 3 --filelimit 100 --dirsfirst \
      -C --noreport' --preview-window right --bind \
      'ctrl-p:change-preview-window(up|hidden|right)')"
  test -z $selected_dir && return
  cd $selected_dir
  # if this is missing, prompt shows old directory till another command runs
  zle reset-prompt
}
zle -N __find_repos
bindkey "^f" __find_repos

eval "$(starship init zsh)"
eval "$(atuin init zsh)"
# `atuin import auto` also needs to be ran after initial install

function __theme_helper() {
  local themes=(
  'gruvbox-dark' 'gruvbox-light'
  'rose-pine' 'rose-pine-moon-dark' 'rose-pine-dawn-light'
  'mellow' 'ayu-dark' 'ayu-light' 'everforest-dark' 'everforest-light' 'oxocarbon'
  'tokyonight-storm' 'oh-lucy' 'oh-lucy-evening' 'nord'
  'nightfox' 'dawnfox' 'duskfox' 'terafox' 'carbonfox'
  'melange-light' 'melange-dark' 'kanagawa'
  'catppuccin-latte' 'catppuccin-frappe' 'catppuccin-mocha' 'catppuccin-macchiato'
  'night-owl' 'nordic' 'poimandres' 'moonbow'
  'github-dark' 'github-light'
  'caret-dark' 'caret-light' 'miasma'
  'monet-light' 'monet-dark' 'neofusion' 'seoul256-dark' 'seoul256-light'
  )
  typeset -A custom_kitty_themes
  local custom_kitty_themes=(
    [oxocarbon]='carbonfox'
  )
  local kitty_conf=~/.config/kitty
  local current_kitty_theme_path="$kitty_conf/current-theme.conf"
  local nvim_themefile=~/.config/nvim/lua/ebozkurt/themes.lua
  if [[ "$1" == "get_themes" ]]; then
	echo $themes
	return
  fi
  if [[ "$1" == "get_custom_kitty_theme" ]]; then
	local kitty_theme="$2"
	if [[ ! -z $custom_kitty_themes[$2] ]]; then
		kitty_theme=$custom_kitty_themes[$2]
	fi
	echo $kitty_theme
	return
  fi
  if [[ "$1" == "get_current_kitty_theme_path" ]]; then
	echo $current_kitty_theme_path
	return
  fi
  if [[ "$1" == "current_nvim_theme" ]]; then
	current_nvim_theme=$(cat $nvim_themefile | head -n 1 | awk '{print $4}' | sed -e 's/^.//' -e 's/.$//')
	echo $current_nvim_theme
	return
  fi
  if [[ "$1" == "find_kitty_theme_name" ]]; then
	local kitty_theme_filename=$(__theme_helper get_custom_kitty_theme $2)
	local theme_name=$(cat $kitty_conf/themes/$kitty_theme_filename.conf | grep name: | sed -e "s/## name: //")
	if [[ -z "$theme_name" ]]; then
	  # for some reason some first letters of some themes are capitalized
	  if ! kitty +kitten themes --dump-theme "$kitty_theme_filename" > /dev/null 2>&1; then
		  echo "$kitty_theme_filename" | perl -nE 'say ucfirst'
		  return
	  fi
	  echo "$2"
	  return
	fi
    echo $theme_name
    return
  fi
  if [[ "$1" == "set_kitty_theme" ]]; then
	local kitty_theme=$(__theme_helper get_custom_kitty_theme $2)
	if [[ -f $kitty_conf/themes/$kitty_theme.conf ]]; then
	  cp $kitty_conf/themes/$kitty_theme.conf $kitty_conf/current-theme.conf
	else
	  nvim_remote_exec "<cmd>lua require('ebozkurt.theme-gen').generate()<cr>" > /dev/null 2>&1
	fi
	# SIGUSR1 reloads kitty config
	~/bin/helpers/tmux_status_color.sh
	__reload_kitty_config
	__reload_wezterm_config
	return
  fi
  if [[ "$1" == "preview_theme" ]]; then
	# this one is a bit faster, but updates kitty.conf as well. Both options reload kitty config.
	# local kitty_theme_filename=$(__theme_helper get_custom_kitty_theme $2)
	# local kitty_theme=$(__theme_helper find_kitty_theme_name $kitty_theme_filename)
	# kitty +kitten themes "$kitty_theme"
	local kitty_theme=$(__theme_helper get_custom_kitty_theme $2)
	# if existing kitty_theme we can do things in parallel
	if [[ -f $kitty_conf/themes/$kitty_theme.conf ]]; then
	  __theme_helper set_nvim_theme $2 &
	  __theme_helper set_kitty_theme $2 &
	# we will attempt to generate kitty_theme, so nvim one should be set first
	else
	  __theme_helper set_nvim_theme $2
	  __theme_helper set_kitty_theme $2 &
	fi
	return
  fi
  if [[ "$1" == "set_nvim_theme" ]]; then
	sed -i '' "1s/.*/local selected_theme = \'$2\'/" $nvim_themefile
	nvim_remote_exec "<cmd>lua ReloadTheme()<cr>" > /dev/null 2>&1 
	return
  fi
}

function __change_theme() {
  current_nvim_theme=$(__theme_helper current_nvim_theme)
  local selected_theme=$(echo "$(__theme_helper get_themes)" | tr ' ' '\n' | grep -v "^$current_nvim_theme$" | sort | \
	  { echo $current_nvim_theme ; xargs echo ; } | tr ' ' '\n' | fzf --preview 'source ~/.zshrc; __theme_helper preview_theme {}' --preview-window 0)
  if [[ -z $selected_theme ]]; then
	__theme_helper set_kitty_theme $current_nvim_theme
	__theme_helper set_nvim_theme $current_nvim_theme
  else
	__theme_helper set_kitty_theme $selected_theme
	__theme_helper set_nvim_theme $selected_theme
  fi
  zle reset-prompt
}

zle -N __change_theme
# alt t
bindkey "^[t" __change_theme
bindkey "^k" clear-screen

function __open_pr {
  local p="$(~/Documents/bitbar_plugins/github-prs.5m.sh fzf)"
  local content="$(cat <(test ${#p[@]} -ne 0 && echo $p))"
  if [[ $1 == 'cmd' ]]; then
    echo "$content"
    return
  fi
  local selected="$(cat <(test ${#p[@]} -ne 0 && echo $p) | fzf --bind \
    'ctrl-f:reload(source ~/.zshrc; __open_pr cmd),ctrl-e:reload(source ~/.zshrc; __open_pr cmd | grep $GH_USERNAME || true)')"
  test -z $selected && return
  echo $selected | awk '{print $NF}' | xargs open
  zle reset-prompt
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
bindkey "^[b" __bt_device_toggle 

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

function __reload_kitty_config {
  pgrep kitty | xargs kill -SIGUSR1
}

# in most cases wezterm reloads its own config, however when we change theme we need to notify wezterm(as we convert theme from kitty one dynamicly)
function __reload_wezterm_config {
  touch ~/dotfiles/wezterm/.config/wezterm/wezterm.lua
}

function __wezterm_change_font() {
  sed -i '' "3s/.*/M.font = \'$1\'/" ~/dotfiles/wezterm/.config/wezterm/overrides.lua;
}


function __kitty_change_font() {
  sed -i '' "3s/.*/font_family $1/" ~/dotfiles/kitty/.config/kitty/toggled-settings.conf;
  __reload_kitty_config
}

function __kitty_font_changer() {
  local current_font=$(sed -n '3p' ~/dotfiles/kitty/.config/kitty/toggled-settings.conf | tr ' ' '\n' | tail -n 1)
  echo $current_font
  local fonts=(
    'FiraCode-Retina'
    'VictorMono-Regular'
    'JetBrainsMono-Regular'
    'IBMPlexMono'
    'InputMonoNarrow-Regular'
    'NotoSansMono-Regular'
    'Iosevka'
    'BerkeleyMono-Regular'
  )
  local selected_font=$(echo $fonts | tr ' ' '\n' | sort | grep -v $current_font | \
    { echo $current_font ; xargs echo ; } | tr ' ' '\n' | fzf --preview 'source ~/.zshrc; __kitty_change_font {}' --preview-window 0)
  if [[ ! -z $selected_font ]]; then
    __kitty_change_font "$selected_font"
  else
    __kitty_change_font "$current_font"
  fi
  zle reset-prompt
}

function __wezterm_font_changer() {
  local current_font=$(sed -n '3p' ~/dotfiles/wezterm/.config/wezterm/overrides.lua | sed -n "s/.*'\(.*\)'/\1/p")
  local fonts=(
  'Fira Code Retina'
  'Victor Mono'
  'JetBrains Mono'
  'IBM Plex Mono'
  'Input Mono Narrow'
  'Noto Sans Mono'
  'Iosevka'
  'Berkeley Mono'
  )

  local selected_font=$(printf "%s\n" "${fonts[@]}" | sort | grep -v "$current_font" | \
  { echo $current_font; cat; } | \
  fzf --preview 'source ~/.zshrc; __wezterm_change_font {}' --preview-window 0)

  if [[ ! -z $selected_font ]]; then
    __wezterm_change_font "$selected_font"
  else
    __wezterm_change_font "$current_font"
  fi
  zle reset-prompt
}

zle -N __wezterm_font_changer
bindkey "^g" __wezterm_font_changer

function __kitty_toggle_transparency() {
  local file="$HOME/dotfiles/kitty/.config/kitty/toggled-settings.conf"
  local lineNum='4'

  # Check if the line is commented
  if sed -n "${lineNum}p" $file | grep -q '^# '; then
    sed -i '' "${lineNum}s/^# //" $file
    nvim_remote_exec "<cmd>TransparentEnable<cr>" > /dev/null 2>&1
  else
    sed -i '' "${lineNum}s/^/# /" $file
    nvim_remote_exec "<cmd>TransparentDisable<cr>" > /dev/null 2>&1
  fi

  # After reloading config menubar even on full screen for some reason with new changes, but obviously possible to toggle fullscreen again manually
  __reload_kitty_config
}

function __wezterm_toggle_transparency() {
  local file="$HOME/dotfiles/wezterm/.config/wezterm/overrides.lua"
  local lineNum='4'

  # Check if the line is commented
  if sed -n "${lineNum}p" $file | grep -q '^-- '; then
    sed -i '' "${lineNum}s/^-- //" $file
    nvim_remote_exec "<cmd>TransparentEnable<cr>" > /dev/null 2>&1
  else
    sed -i '' "${lineNum}s/^/-- /" $file
    nvim_remote_exec "<cmd>TransparentDisable<cr>" > /dev/null 2>&1
  fi
}

function __term_toggle_transparency() {
  __wezterm_toggle_transparency
  __kitty_toggle_transparency
}

function __kitty_change_setting() {
  local file="$HOME/dotfiles/kitty/.config/kitty/toggled-settings.conf"
  local lineNum=$1
  local ops=("toggle" "enable" "disable")
  local op="toggle"

  if [[ " ${ops[*]} " =~ " $2 " ]]; then
    local op="$2"
  fi

  if [[ "$op" = "toggle" ]]; then
    # Check if the line is commented
    if sed -n "${lineNum}p" $file | grep -q '^# '; then
      sed -i '' "${lineNum}s/^# //" $file
    else
      sed -i '' "${lineNum}s/^/# /" $file
    fi
  elif [[ "$op" = "enable" ]]; then
      sed -i '' "${lineNum}s/^# //" $file
  else
      sed -i '' "${lineNum}s/^# //" $file
      sed -i '' "${lineNum}s/^/# /" $file
  fi

  __reload_kitty_config
}

function __wezterm_change_setting() {
  local file="$HOME/dotfiles/wezterm/.config/wezterm/overrides.lua"
  local lineNum=$1
  local ops=("toggle" "enable" "disable")
  local op="toggle"

  if [[ " ${ops[*]} " =~ " $2 " ]]; then
    local op="$2"
  fi

  if [[ "$op" = "toggle" ]]; then
    # Check if the line is commented
    if sed -n "${lineNum}p" $file | grep -q '^-- '; then
      sed -i '' "${lineNum}s/^-- //" $file
    else
      sed -i '' "${lineNum}s/^/-- /" $file
    fi
  elif [[ "$op" = "enable" ]]; then
      sed -i '' "${lineNum}s/^-- //" $file
  else
      sed -i '' "${lineNum}s/^-- //" $file
      sed -i '' "${lineNum}s/^/-- /" $file
  fi
}

function __term_change_setting() {
__kitty_change_setting $1 $2
__wezterm_change_setting $1 $2
}
