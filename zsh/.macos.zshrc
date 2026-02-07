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

# mise
eval "$(mise activate zsh)"
# zsh-autosuggestions
source ~/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept

alias ss='echo $__sourced_states'

eval "$(direnv hook zsh)"
export DIRENV_LOG_FORMAT=""

function nvim_remote_exec() {
  local msg="$1"
  local pc="${pc:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

  setopt local_options null_glob

  local base
  base="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)"
  [[ -z "$base" ]] && base="${TMPDIR:-/tmp}"
  base="${base%/}"

  local -a candidates
  candidates=(
    # no nix shell
    "$base"/nvim.*/*/nvim.*.0
    "$base"/nvim.*/*/*/nvim.*.0

    # nix shell inserts an extra dir level like nix-shell.*
    "$base"/nix-shell.*/nvim.*/*/nvim.*.0
    "$base"/nix-shell.*/nvim.*/*/*/nvim.*.0

    # (optional) flakes sometimes use other nix temp prefixes
    "$base"/nix-*/nvim.*/*/nvim.*.0
    "$base"/nix-*/nvim.*/*/*/nvim.*.0
  )

  local -a live
  live=()
  local a
  for a in "${candidates[@]}"; do
    [[ -S "$a" || -p "$a" ]] || continue
    nvim --server "$a" --remote-expr "1" >/dev/null 2>&1 && live+=("$a")
  done

  (( ${#live[@]} == 0 )) && return 0

  printf '%s\n' "${live[@]}" | xargs -n 1 -P "$pc" -I {} \
    nvim --server {} --remote-send "$msg" >/dev/null 2>&1
}

# Attempts to find and kill nvim instances that are not connected to a tty
# Any instance which has a parent connected to tty should not be killed
function nvim_kill_non_tty {
  awk 'NR==FNR{pc[$1]=$2;next} $3=="nvim" && $0 ~ /--embed|--headless|--server/ && pc[$2]!="nvim"{print $1}' <(ps -axo pid=,comm=) <(ps -axo pid=,ppid=,comm=,args=) | xargs -n1 kill -9
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

alias cat='bat --paging=never'
alias lg='lazygit'

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
  'melange-light' 'melange-dark' 'kanagawa' 'kanagawa-dragon' 'kanagawa-lotus'
  'catppuccin-latte' 'catppuccin-frappe' 'catppuccin-mocha' 'catppuccin-macchiato'
  'night-owl' 'nordic' 'poimandres' 'moonbow'
  'github-dark' 'github-light'
  'caret-dark' 'caret-light' 'miasma'
  'monet-light' 'monet-dark' 'neofusion' 'seoul256-dark' 'seoul256-light'
  'zenbones-light' 'zenbones-dark'
  'neobones-light' 'neobones-dark'
  'kanso-zen' 'kanso-ink' 'kanso-pearl'
  'teide-darker' 'teide-dark' 'teide-dimmed' 'teide-light'
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
	~/bin/helpers/kitty-to-ghostty ~/.config/kitty/current-theme.conf ~/.config/ghostty/theme
	__reload_ghostty_config
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

  if [[ $1 == 'open' ]]; then
    shift
    for pr in "$@"; do
      echo "$pr" | awk '{print $NF}' | xargs open
    done
    return
  fi

  local selected_output="$(
    cat <(test ${#p[@]} -ne 0 && echo $p) | fzf --multi --expect=enter \
      --bind 'ctrl-f:reload(source ~/.zshrc; __open_pr cmd)' \
      --bind 'ctrl-e:reload(source ~/.zshrc; __open_pr cmd | grep \$GH_USERNAME || true)' \
      --bind 'alt-f:reload(source ~/.zshrc; __open_pr cmd | grep -v app/dependabot || true)' \
      --bind 'ctrl-p:execute((source ~/.zshrc; __open_pr open {+}) &)+deselect-all' \
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

function __reload_kitty_config {
  pgrep kitty | xargs kill -SIGUSR1
}

# in most cases wezterm reloads its own config, however when we change theme we need to notify wezterm(as we convert theme from kitty one dynamicly)
function __reload_wezterm_config {
  touch ~/dotfiles/wezterm/.config/wezterm/wezterm.lua
}

function __reload_ghostty_config {
  osascript <<'APPLESCRIPT'
tell application "Ghostty" to activate
tell application "System Events" to keystroke "," using {command down, shift down}

# doing this so that `mouse-hide-while-typing` works
# without toggling focused application manually
ignoring application responses
  tell application "Finder" to activate
  tell application "Ghostty" to activate
end ignoring
APPLESCRIPT
}

function __wezterm_change_font() {
  sed -i '' "3s/.*/M.font = \'$1\'/" ~/dotfiles/wezterm/.config/wezterm/overrides.lua;
}


function __kitty_change_font() {
  sed -i '' "3s/.*/font_family $1/" ~/dotfiles/kitty/.config/kitty/toggled-settings.conf;
  __reload_kitty_config
}

function __ghostty_change_font() {
  sed -i '' "3s/.*/font-family = \"$1\"/" ~/dotfiles/ghostty/.config/ghostty/overrides;
  __reload_ghostty_config
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

function __ghostty_font_changer() {
  local current_font=$(sed -n '3p' ~/dotfiles/ghostty/.config/ghostty/overrides | sed -n 's/.*= "\(.*\)"/\1/p')
  local fonts=(
  'Fira Code Retina'
  'Victor Mono'
  'JetBrains Mono'
  'IBM Plex Mono'
  'Input Mono Narrow'
  # todo: this looks a bit weird look into it
  'Noto Sans Mono'
  'Iosevka'
  'Berkeley Mono'
  'Cascadia Code'
  )

  local selected_font=$(printf "%s\n" "${fonts[@]}" | sort | grep -v "$current_font" | \
  { echo $current_font; cat; } | \
  fzf --preview 'source ~/.zshrc; __ghostty_change_font {}' --preview-window 0)


  if [[ ! -z $selected_font ]]; then
    __ghostty_change_font "$selected_font"
  else
    __ghostty_change_font "$current_font"
  fi
  zle reset-prompt
}

zle -N __ghostty_font_changer
bindkey "^g" __ghostty_font_changer

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

function __ghostty_toggle_transparency() {
  local file="$HOME/dotfiles/ghostty/.config/ghostty/overrides"
  local lineNum='4'

  # Check if the line is commented
  if sed -n "${lineNum}p" $file | grep -q '^# '; then
    sed -i '' "${lineNum}s/^# //" $file
    nvim_remote_exec "<cmd>TransparentEnable<cr>" > /dev/null 2>&1
  else
    sed -i '' "${lineNum}s/^/# /" $file
    nvim_remote_exec "<cmd>TransparentDisable<cr>" > /dev/null 2>&1
  fi

  __reload_ghostty_config
}

function __term_toggle_transparency() {
  __wezterm_toggle_transparency
  __kitty_toggle_transparency
  __ghostty_toggle_transparency
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

function __ghostty_change_setting() {
  local file="$HOME/dotfiles/ghostty/.config/ghostty/overrides"
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

  __reload_ghostty_config
}

function __term_change_setting() {
__kitty_change_setting $1 $2
__wezterm_change_setting $1 $2
__ghostty_change_setting $1 $2
}

_load_custom_zsh_on_dir
