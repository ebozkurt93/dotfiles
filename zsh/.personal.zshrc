export PATH=$PATH:~/bin
export EDITOR=nvim
export GH_USERNAME=ebozkurt93
export COPILOT_ENABLED=false
export COPILOT_ENABLED_PATH=""
export HEADSCALE_URL="https://hs.erdem-bozkurt.com"

unset LC_ALL
export LANG="en_GB.UTF-8"
export LC_TIME="en_GB.UTF-8"

# claude code fails to run shell commands without this addition
# This also works: `[[ -o interactive ]] || return`
[[ "$SNAPSHOT_FILE" == */.claude/shell-snapshots/* ]] && return

# Functions
function mcd
{
  command mkdir -p $1 && cd $1
}

# enables vi mode for zsh
bindkey -v

# edit prompt in $EDITOR with Alt+e
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd '^[e' edit-command-line  # Alt+e in normal mode

bracketed-paste() {
  zle .$WIDGET && LBUFFER=${LBUFFER%$'\n'}
}
zle -N bracketed-paste

function is_macos {
  [ "$(uname 2> /dev/null)" = "Darwin" ]
}

# convenience aliases
alias cd..='cd ..'
alias ..='cd ..'
alias cd...='cd ../..'
alias ch='cd ~'
alias ...='cd ../..'
if command -v eza > /dev/null; then
  alias ls='eza --icons=auto'
fi
alias l='ls -lF'
alias dir='ls'
alias la='ls -lah'
alias ll='ls -l'
alias vi='nvim'
alias vim='nvim'
alias viconf='(cd ~/dotfiles/nvim/.config/nvim && vi)'
alias vidotfiles='(cd ~/dotfiles/ && vi)'
alias vibackups='(cd ~/.vim/backups && vi)'
alias dsync='echo "$(cd ~/dotfiles/ && git pull && cd ~/dotfiles/scripts && ./stow.sh -R)"'
alias hma='(cd ~/dotfiles && mise deactivate && nix run .#homeConfigurations.erdembozkurt.activationPackage)'
alias sr='exec $SHELL'
alias nn='cd ~/Documents; cd `ls | grep Notes`; nvim'

alias ns='nix-shell --run $SHELL'
alias nd='nix develop -c $SHELL'

source ~/bin/helpers/colors.sh

function __nvim_launch_with_custom_config() {
  local config=$(find ~/.config -maxdepth 1 -iname '*nvim*' | fzf --prompt="Neovim Configs > " --layout=reverse --border --exit-0)
 
  [[ -z $config ]] && echo "No config selected" && zle reset-prompt && return
 
  NVIM_APPNAME=$(basename $config) nvim $@
}
zle -N __nvim_launch_with_custom_config
bindkey "^v" __nvim_launch_with_custom_config
# alias vt='NVIM_APPNAME=nvim-test nvim'

alias gpristine='git reset --hard && git clean -df'
alias remove_node_modules="find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +"

# docker
alias lzd='lazydocker'
alias d='docker'
alias dr='docker run --rm -i -t'
alias dx='docker exec -i -t'
function drr { docker stop "$1" && docker rm "$1" }
alias dps='docker ps -a'
alias db='docker build -t'
# remove all stopped docker containers
alias drm="d ps -a | grep Exited | awk '{print $1}' | tr '\n' ' ' | xargs docker rm"

# docker-compose
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# tmux
alias t='tmux'
alias ta='t a'

alias yt='docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v "$(pwd)":/workdir:rw mikenye/youtube-dl'
alias ffmpeg='docker run --rm -i -t -v $PWD:/tmp/workdir jrottenberg/ffmpeg'
function pandoc() {
  local dockerfile_dir="$HOME/dotfiles/docker"
  local dockerfile_name="pandoc.Dockerfile"
  local image_name="pandoc-custom"

  if [[ "$(docker images -q $image_name 2> /dev/null)" == "" ]]; then
    echo "Building Docker image..."
    docker build -t $image_name -f "$dockerfile_dir/$dockerfile_name" $dockerfile_dir
  fi

  docker run --rm --volume "$(pwd):/data" $image_name "$@"
}
alias bw-unlock='export BW_SESSION=$(bw unlock --raw)'
export SOPS_AGE_KEY_FILE=$HOME/sops/age/keys.txt

function __get_pid_for_port() {
  echo "$(lsof -i:$1 -t)"
}

function pk() {
  __get_pid_for_port $1 | xargs kill
}

# https://stackoverflow.com/questions/11532157/remove-duplicate-lines-without-sorting
alias unique="awk '!x[\$0]++'"

function __execute_package_json_command() {
  local install_deps_command="install_deps"
  if [[ ! -f  "package.json" ]]; then
    # this is the default behaviour for zsh in ctrl-p, so doing that in default case
    zle up-history
    return
  fi

  typeset -A info
  local info=(
    [yarn-run_cmd]="yarn"
    [yarn-install_cmd]="yarn install"
    [yarn-lockfiles]="yarn.lock"
    [npm-run_cmd]="npm run"
    [npm-install_cmd]="npm install"
    [npm-lockfiles]="package-lock.json"
    [pnpm-run_cmd]="pnpm"
    [pnpm-install_cmd]="pnpm install"
    [pnpm-lockfiles]="pnpm-lock.yaml"
    [bun-run_cmd]="bun run"
    [bun-install_cmd]="bun install"
    [bun-lockfiles]="bun.lock bun.lockb"
)
  local cmd_alternatives=$(echo "${(k)info}" | tr " " "\n" | cut -d'-' -f1 | sort | uniq | tr "\n" " " | xargs)
  local op='yarn'
  # split by space as separator
  for c in ${(s: :)cmd_alternatives}
  do
    for lockfile in ${(s: :)info[$c-lockfiles]}
    do
      if [[ -f "$lockfile" || -f "$(git rev-parse --show-toplevel 2>/dev/null)/$lockfile" ]]; then
        op="$c"
      fi
    done
  done

  local selection=$(cat package.json | jq -r '.scripts | to_entries | .[] | "\(.key) -> \(.value)"')
  selection="$selection\n$install_deps_command"

  local selection=$(echo $selection | fzf --tiebreak='begin,chunk' --bind 'ctrl-p:become(echo _{})+abort')
  [[ -z $selection ]] && return
  if [[ $selection == "$install_deps_command" ]]; then
    cmd="$info[$op-install_cmd]"
    echo ${BOLD}${BRIGHT_BLUE}$cmd${RESET}
    eval $cmd
  elif [[ $selection == "_$install_deps_command" ]]; then
    cmd="$info[$op-install_cmd]"
    echo $cmd | pbcopy
    echo "Copied install dependencies command ($cmd) to clipboard"
  elif [[ $selection =~ ^_.* ]]; then
    cmd=$(echo "$info[$op-run_cmd] $(echo "$selection" | awk -F '->' '{print $1}' | cut -c2- | xargs)")
    echo $cmd | pbcopy
    echo "Copied command ($cmd) to clipboard"
  else
    cmd=$(echo "$info[$op-run_cmd] $(echo "$selection" | awk -F '->' '{print $1}' | xargs)")
    echo "${BOLD}${BRIGHT_BLUE}$cmd${RESET}"
    eval $cmd </dev/tty
  fi
  zle send-break
}

zle -N __execute_package_json_command
bindkey "^p" __execute_package_json_command

function __execute_makefile_command() {
  local file=""
  local cmd=""

  if [[ -f "Makefile" ]]; then
    file="Makefile"
    cmd="make"
  elif [[ -f "justfile" ]]; then
    file="justfile"
    cmd="just"
  else
    echo "No Makefile or justfile found"
    zle send-break
    return
  fi

  local selection=$(awk -F: '/^[a-zA-Z0-9_-]+:/ { print $1 }' $file | sort -u | fzf --tiebreak='begin,chunk')
  [[ -z $selection ]] && return
  echo "${BOLD}${BRIGHT_BLUE}$cmd $selection${RESET}"
  $cmd $selection </dev/tty
  zle send-break
}

zle -N __execute_makefile_command
bindkey "^[m" __execute_makefile_command

function __ch() {
  ch
  zle reset-prompt
}

zle -N __ch
bindkey "^[h" __ch

function __cd_to_git_repo_root {
  local d=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ ! -z "$d" ]] && cd "$d"
  zle accept-line
}

zle -N __cd_to_git_repo_root
bindkey "^h" __cd_to_git_repo_root

function __cd_fzf {
  local selection=$(find . \( -name ".git" -o -name "node_modules" -o -path "*/.*" \) \
    -prune -o -type d -print -maxdepth 4 > /dev/null 2>&1| fzf)
  [[ -z $selection ]] && return
  cd $selection
  zle reset-prompt
}

zle -N __cd_fzf
bindkey "^[f" __cd_fzf

function __find_and_run_executable {
  local selection=$(find . -maxdepth 4 -perm -111 -type f | fzf --bind 'ctrl-p:become(echo _{})+abort')
  [[ -z $selection ]] && return
  if [[ $selection =~ ^_.* ]]; then
    selection="$(echo "$selection" | cut -c2-)"
    dname=$(dirname $selection)
    filename=$(basename $selection)
    cd $dname
    echo "./$filename" | pbcopy
    echo "Copied command (./$filename) to clipboard"
  else
    pwd="$PWD"
    dname=$(dirname $selection)
    filename=$(basename $selection)
    cd $dname
    ./$filename
    cd $pwd
  fi
  zle send-break
}

zle -N __find_and_run_executable
bindkey "^[r" __find_and_run_executable

function withenv {
  [ $# -lt 2 ] && { echo "Usage: withenv ENVFILE COMMAND [ARGS...]" >&2; return 1; }

  local envfile=$(realpath "$1" 2>/dev/null) || { echo "withenv: env file '$1' not found" >&2; return 1; }
  shift

  (set -a; . "$envfile"; exec "${SHELL:-/bin/sh}" -c "$*")
}

__sourced_states=()
function _load_custom_zsh_on_dir () {
	if [[ ! -z $__custom_state && -f $HOME/.$__custom_state.zshrc ]]; then
	  source $HOME/.$__custom_state.zshrc
	  __sourced_states+=($__custom_state)
	fi
	local states=($(~/bin/state-switcher enabled-states))
	for state in "${states[@]}"; do
	  if [[ $state == 'personal' ]]; then
	    # this one is unique, always sourced it by default
	    continue
	  fi
	  if [[ -f $HOME/.$state.zshrc && ! " ${__sourced_states[*]} " =~ " ${state} " ]]; then
	    local __paths=($(~/bin/state-switcher state-paths $state))
	    if $(~/bin/state-switcher always-sourced-if-enabled $state); then
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

alias ss='echo $__sourced_states'

local function __state_switcher_toggle() {
  local p=~/bin/state-switcher
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

function __open_folder() {
  if is_macos; then
    open .
  else
    xdg-open .
  fi
}

zle -N __open_folder
bindkey "^[o" __open_folder

function __bt_device_toggle() {
  if ! is_macos; then
    echo "TODO(linux): __bt_device_toggle not ported yet (blueutil-specific)"
    zle send-break
    return
  fi
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
  if ! is_macos; then
    echo "TODO(linux): wp_change not ported yet (set_wallpaper.sh is macOS-only)"
    return
  fi
  local wp_file=$(~/bin/helpers/set_wallpaper.sh wp-path)
  local selection=$(~/bin/helpers/set_wallpaper.sh find | fzf --preview 'viu -b {}')
  [[ -z $selection ]] && return
  echo -e "$selection\n$(cat $wp_file)" > $wp_file
  ~/bin/helpers/set_wallpaper.sh
}

function __sed_inplace() {
  if is_macos; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

alias cat='bat --paging=never'
alias lg='lazygit'

# mise
eval "$(mise activate zsh)"
# zsh-autosuggestions
source ~/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept

eval "$(direnv hook zsh)"
export DIRENV_LOG_FORMAT=""

eval "$(starship init zsh)"
eval "$(atuin init zsh)"
# `atuin import auto` also needs to be ran after initial install

function __nvim_cmd() {
  if [[ -x "$HOME/.nix-profile/bin/nvim" ]]; then
    echo "$HOME/.nix-profile/bin/nvim"
    return
  fi
  if [[ -x "$HOME/bin/nvim" ]]; then
    echo "$HOME/bin/nvim"
    return
  fi

  command -v nvim
}

function nvim_remote_exec() {
  # $1 is a plain ex-command string, e.g. "lua Foo()"
  local msg="$1"
  local pc="${pc:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"
  local nvim_cmd="$(__nvim_cmd)"
  [[ -z "$nvim_cmd" ]] && return 1

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
    "$nvim_cmd" --server "$a" --remote-expr "1" >/dev/null 2>&1 && live+=("$a")
  done

  (( ${#live[@]} == 0 )) && return 0

  local escaped_msg="${msg//\'/\'\'}"
  printf '%s\n' "${live[@]}" | xargs -n 1 -P "$pc" -I {} \
    "$nvim_cmd" --server {} --remote-expr "execute('$escaped_msg')" >/dev/null 2>&1
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
  'teide-darker' 'teide-dark' 'teide-dimmed' 'teide-light' 'carvion'
  'ember' 'ember-soft' 'ember-light'
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
	  nvim_remote_exec "lua require('ebozkurt.theme-gen').generate('$kitty_theme')" > /dev/null 2>&1
	  if [[ ! -f $kitty_conf/themes/$kitty_theme.conf ]]; then
	    local nvim_cmd="$(__nvim_cmd)"
	    [[ -n "$nvim_cmd" ]] && "$nvim_cmd" --headless -c "lua require('ebozkurt.theme-gen').generate('$kitty_theme')" -c qa > /dev/null 2>&1
	  fi
	  if [[ ! -f $kitty_conf/themes/$kitty_theme.conf ]]; then
	    echo "Could not generate kitty theme for $2" >&2
	    return 1
	  fi
	  cp $kitty_conf/themes/$kitty_theme.conf $kitty_conf/current-theme.conf
	  rm $kitty_conf/themes/$kitty_theme.conf
	fi
	# SIGUSR1 reloads kitty config
	~/bin/helpers/tmux_status_color.sh
	__reload_kitty_config
	__reload_wezterm_config
	~/bin/helpers/kitty-to-ghostty ~/.config/kitty/current-theme.conf ~/.config/ghostty/theme
	is_macos && __reload_ghostty_config
	return
  fi
  if [[ "$1" == "preview_theme" ]]; then
	__theme_helper set_nvim_theme $2
	__theme_helper set_kitty_theme $2
	return
  fi
  if [[ "$1" == "set_nvim_theme" ]]; then
	__sed_inplace "1s/.*/local selected_theme = \'$2\'/" $nvim_themefile
	nvim_remote_exec "lua ReloadTheme()" > /dev/null 2>&1
	return
  fi
}

function __change_theme() {
  current_nvim_theme=$(__theme_helper current_nvim_theme)
  local selected_theme=$(echo "$(__theme_helper get_themes)" | tr ' ' '\n' | grep -v "^$current_nvim_theme$" | sort | \
	  { echo $current_nvim_theme ; xargs echo ; } | tr ' ' '\n' | fzf --preview 'source ~/.zshrc; __theme_helper preview_theme {}' --preview-window 0)
  if [[ -z $selected_theme ]]; then
	__theme_helper set_nvim_theme $current_nvim_theme
	__theme_helper set_kitty_theme $current_nvim_theme
  else
	__theme_helper set_nvim_theme $selected_theme
	__theme_helper set_kitty_theme $selected_theme
  fi
  zle reset-prompt
}

zle -N __change_theme
# alt t
bindkey "^[t" __change_theme
bindkey "^k" clear-screen

function __reload_kitty_config {
  local -a pids
  pids=(${(f)"$(command pgrep -x kitty 2>/dev/null || true)"})
  (( ${#pids[@]} == 0 )) && return

  kill -SIGUSR1 "${pids[@]}"
}

# in most cases wezterm reloads its own config, however when we change theme we need to notify wezterm(as we convert theme from kitty one dynamicly)
function __reload_wezterm_config {
  touch ~/dotfiles/wezterm/.config/wezterm/wezterm.lua
}

function __wezterm_change_font() {
  __sed_inplace "3s/.*/M.font = \'$1\'/" ~/dotfiles/wezterm/.config/wezterm/overrides.lua
}

function __kitty_change_font() {
  __sed_inplace "3s/.*/font_family $1/" ~/dotfiles/kitty/.config/kitty/toggled-settings.conf
  __reload_kitty_config
}

function __ghostty_change_font() {
  __sed_inplace "3s/.*/font-family = \"$1\"/" ~/dotfiles/ghostty/.config/ghostty/overrides
  is_macos && __reload_ghostty_config
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
    __sed_inplace "${lineNum}s/^# //" $file
    nvim_remote_exec "TransparentEnable" > /dev/null 2>&1
  else
    __sed_inplace "${lineNum}s/^/# /" $file
    nvim_remote_exec "TransparentDisable" > /dev/null 2>&1
  fi

  # After reloading config menubar even on full screen for some reason with new changes, but obviously possible to toggle fullscreen again manually
  __reload_kitty_config
}

function __wezterm_toggle_transparency() {
  local file="$HOME/dotfiles/wezterm/.config/wezterm/overrides.lua"
  local lineNum='4'

  # Check if the line is commented
  if sed -n "${lineNum}p" $file | grep -q '^-- '; then
    __sed_inplace "${lineNum}s/^-- //" $file
    nvim_remote_exec "TransparentEnable" > /dev/null 2>&1
  else
    __sed_inplace "${lineNum}s/^/-- /" $file
    nvim_remote_exec "TransparentDisable" > /dev/null 2>&1
  fi
}

function __ghostty_toggle_transparency() {
  local file="$HOME/dotfiles/ghostty/.config/ghostty/overrides"
  local lineNum='4'

  # Check if the line is commented
  if sed -n "${lineNum}p" $file | grep -q '^# '; then
    __sed_inplace "${lineNum}s/^# //" $file
    nvim_remote_exec "TransparentEnable" > /dev/null 2>&1
  else
    __sed_inplace "${lineNum}s/^/# /" $file
    nvim_remote_exec "TransparentDisable" > /dev/null 2>&1
  fi

  is_macos && __reload_ghostty_config
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
      __sed_inplace "${lineNum}s/^# //" $file
    else
      __sed_inplace "${lineNum}s/^/# /" $file
    fi
  elif [[ "$op" = "enable" ]]; then
      __sed_inplace "${lineNum}s/^# //" $file
  else
      __sed_inplace "${lineNum}s/^# //" $file
      __sed_inplace "${lineNum}s/^/# /" $file
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
      __sed_inplace "${lineNum}s/^-- //" $file
    else
      __sed_inplace "${lineNum}s/^/-- /" $file
    fi
  elif [[ "$op" = "enable" ]]; then
      __sed_inplace "${lineNum}s/^-- //" $file
  else
      __sed_inplace "${lineNum}s/^-- //" $file
      __sed_inplace "${lineNum}s/^/-- /" $file
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
      __sed_inplace "${lineNum}s/^# //" $file
    else
      __sed_inplace "${lineNum}s/^/# /" $file
    fi
  elif [[ "$op" = "enable" ]]; then
      __sed_inplace "${lineNum}s/^# //" $file
  else
      __sed_inplace "${lineNum}s/^# //" $file
      __sed_inplace "${lineNum}s/^/# /" $file
  fi

  is_macos && __reload_ghostty_config
}

function __term_change_setting() {
__kitty_change_setting $1 $2
__wezterm_change_setting $1 $2
__ghostty_change_setting $1 $2
}

if is_macos; then
  source $HOME/.macos.zshrc
fi
