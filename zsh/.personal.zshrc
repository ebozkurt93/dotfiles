export PATH=$PATH:~/bin
export GH_USERNAME=ebozkurt93
export COPILOT_ENABLED=false
export COPILOT_ENABLED_PATH=""
# Functions
function mcd
{
  command mkdir -p $1 && cd $1
}

# enables vi mode for zsh
bindkey -v

bracketed-paste() {
  zle .$WIDGET && LBUFFER=${LBUFFER%$'\n'}
}
zle -N bracketed-paste

if [ "$(uname 2> /dev/null)" = "Darwin" ]; then
  # Change iterm2 profile. Usage it2prof ProfileName (case sensitive)
  it2prof() { echo -e "\033]50;SetProfile=$1\a" }

  alias code='open -a /Applications/Visual\ Studio\ Code.app/'
  alias smerge='open -a /Applications/Sublime\ Merge.app/'

  # homebrew related settings
  # asdf
  . /opt/homebrew/opt/asdf/libexec/asdf.sh
  . ~/.asdf/plugins/java/set-java-home.zsh
	export PATH=$PATH:~/.asdf/installs/golang/1.19.1/packages/bin
  # fzf
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  # zsh-autosuggestions
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  bindkey '^ ' autosuggest-accept
fi

# convenience aliases
alias cd..='cd ..'
alias ..='cd ..'
alias cd...='cd ../..'
alias ch='cd ~'
alias ...='cd ../..'
alias ls='ls -G'
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
alias sr='exec $SHELL'
alias ss='echo $__sourced_states'
local function __state_switcher_toggle() {
  local p=~/Documents/bitbar_plugins/state-switcher.5m.sh
  local selected_state=$($p states-with-marks | sort | fzf \
    --bind 'ctrl-space:execute(echo _{})+abort,alt-j:execute(echo __{})+abort,alt-k:execute(echo ___{})+abort'
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
alias st="__state_switcher_toggle"
zle -N __state_switcher_toggle
bindkey "^[s" __state_switcher_toggle

alias gpristine='git reset --hard && git clean -df'
alias remove_node_modules="find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +"

# docker
alias d='docker'
alias dr='docker run --rm -i -t'
alias dx='docker exec -i -t'
function drr { docker stop "$1" && docker rm "$1" }
alias dps='docker ps -a'
alias db='docker build -t'
# remove all stopped docker containers
alias drm="d ps -a | grep Exited | awk '{print $1}' | tr '\n' ' ' | xargs docker rm"
alias d-stop="docker system info > /dev/null 2>&1 && ( { killall Docker } &)"
alias d-start="open -a /Applications/Docker.app"
alias d-restart="d-stop; sleep 1; d-start && while ! docker system info > /dev/null 2>&1; do sleep 1; done"
alias ds="d-stop || d-start"

# docker-compose
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# tmux
alias t='tmux'

alias cat='bat --paging=never'
alias lg='lazygit'

# running some docker containers
alias torrent-up='docker-compose -f ~/personal-repositories/docker-compose\ files/qbittorrent/docker-compose.yml up -d'
alias torrent-down='docker-compose -f ~/personal-repositories/docker-compose\ files/qbittorrent/docker-compose.yml down'
alias jellyfin-up='docker-compose -f ~/personal-repositories/docker-compose\ files/jellyfin/docker-compose.yml up -d'
alias jellyfin-down='docker-compose -f ~/personal-repositories/docker-compose\ files/jellyfin/docker-compose.yml down'
alias yt='docker run --rm -u $(id -u):$(id -g) -v $PWD:/data vimagick/youtube-dl'
alias ffmpeg='docker run --rm -i -t -v $PWD:/tmp/workdir jrottenberg/ffmpeg'

# alias ledger='docker run --rm -v "$PWD":/data dcycle/ledger:1'
alias ledger='docker run --rm -v "/Users/erdembozkurt/personal-repositories/junk/ledger-data":/data dcycle/ledger:1'
alias ldg='ledger -f /data/sample.dat'


# temporary, refetch apartments 
alias apt-refetch='cd ~/personal-repositories/place-scraper-v2 && go run . -s && curl https://apt-api.erdem-bozkurt.com/refetch'

function nvim_remote_exec {
  local pc="$(nproc)"
  find /var/folders -name '*nvim*' 2>/dev/null | tail -n +2 | xargs -P $pc -I {} nvim --server {} --remote-send "$1"
}

# given a file pattern and commands, this function will rerun commands whenever files change
function res {
  find . -name "$1" | entr -r ${@:2}
}

function resr {
  find . -name "$1" | entr -rs ${@:2}
}

function __find_repos {
  p=($(~/Documents/bitbar_plugins/state-switcher.5m.sh enabled-states-paths) ~/bin)
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

alias dev-rust='res "*.rs" cargo run'
alias dev-go='res "*.go" go run .'

function __get_pid_for_port() {
  echo "$(lsof -i:$1 -t)"
}
function pk() {
  __get_pid_for_port $1 | xargs kill
}
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
  )
  typeset -A custom_kitty_themes
  local custom_kitty_themes=(
    [oxocarbon]='carbonfox'
  )
  local kitty_conf=~/.config/kitty
  local current_kitty_theme_contents=$(cat "$kitty_conf/current-theme.conf")
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
	pgrep kitty | xargs kill -SIGUSR1
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
  local selected_theme=$(echo "$(__theme_helper get_themes)" | tr ' ' '\n' | grep -v $current_nvim_theme | sort | \
	  { echo $current_nvim_theme ; xargs echo ; } | tr ' ' '\n' | fzf --preview 'source ~/.zshrc; __theme_helper preview_theme {}')
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
    [yarn-lockfile]="yarn.lock"
    [npm-run_cmd]="npm run"
    [npm-install_cmd]="npm install"
    [npm-lockfile]="package-lock.json"
    [pnpm-run_cmd]="pnpm"
    [pnpm-install_cmd]="pnpm install"
    [pnpm-lockfile]="pnpm-lock.yaml"
)
  local cmd_alternatives=$(echo "${(k)info}" | tr " " "\n" | cut -d'-' -f1 | sort | uniq | tr "\n" " " | xargs)
  local op='yarn'
  # split by space as separator
  for c in ${(s: :)cmd_alternatives}
  do
    if [[ -f "$info[$c-lockfile]" ]]; then
      op="$c"
    fi
  done

  local selection=$(cat package.json | jq  '.scripts' | sed -e '1d' -e '$d')
  selection="$selection\n$install_deps_command"

  local selection=$(echo $selection | fzf --bind 'ctrl-p:execute(echo _{})+abort')
  [[ -z $selection ]] && return
  if [[ $selection == "$install_deps_command" ]]; then
    cmd="$info[$op-install_cmd]"
    echo $cmd
    eval $cmd
  elif [[ $selection == "_$install_deps_command" ]]; then
    cmd="$info[$op-install_cmd]"
    echo $cmd | pbcopy
    echo "Copied install dependencies command ($cmd) to clipboard"
  elif [[ $selection =~ ^_.* ]]; then
    cmd=$(echo "$info[$op-run_cmd] $(echo "$selection" | cut -c2- | cut -d'"' -f2)")
    echo $cmd | pbcopy
    echo "Copied command ($cmd) to clipboard"
  else
     $info[$op-run_cmd] $(echo "$selection" | cut -d'"' -f2)
  fi
  zle send-break
}

zle -N __execute_package_json_command
bindkey "^p" __execute_package_json_command

function __bt_device_toggle() {
  if [[ "$(blueutil --power)" == "0" ]]; then
    echo 'bluetooth off'
    zle send-break
    return
  fi
  local c=$(blueutil --paired --format json | jq -r \
    '.[] | .name + " " + (.connected|tostring|sub("true"; "✅")|sub("false"; "❌")) + " " + .address')
  local selection=$(echo "$c" | sort | fzf --bind 'ctrl-p:execute(echo _{})+abort')
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

function __ch() {
  ch
  zle reset-prompt
}

zle -N __ch
bindkey "^[h" __ch

function __open_folder() {
  open .
}

function __cd_to_git_repo_root {
  local d=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ ! -z "$d" ]] && cd "$d"
  zle accept-line
}

zle -N __cd_to_git_repo_root
bindkey "^h" __cd_to_git_repo_root

zle -N __open_folder
bindkey "^[o" __open_folder

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
  local selection=$(find . -maxdepth 4 -perm -111 -type f | fzf --bind 'ctrl-p:execute(echo _{})+abort')
  [[ -z $selection ]] && return
  if [[ $selection =~ ^_.* ]]; then
    selection="$(echo "$selection" | cut -c2-)"
    dname=$(dirname $selection)
    filename=$(basename $selection)
    cd $dname
    echo "./$filename" | pbcopy
    echo "Copied command (./$filename) to clipboard"
  else
    dname=$(dirname $selection)
    filename=$(basename $selection)
    cd $dname
    ./$filename
  fi
  zle send-break
}

zle -N __find_and_run_executable
bindkey "^[r" __find_and_run_executable

function __kitty_change_font() {
  sed -i '' "3s/.*/font_family $1/" ~/dotfiles/kitty/.config/kitty/toggled-settings.conf; pgrep kitty | xargs kill -SIGUSR1
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
  )
  local selected_font=$(echo $fonts | tr ' ' '\n' | sort | grep -v $current_font | \
    { echo $current_font ; xargs echo ; } | tr ' ' '\n' | fzf --preview 'source ~/.zshrc; __kitty_change_font {}')
  if [[ ! -z $selected_font ]]; then
    __kitty_change_font "$selected_font"
  else
    __kitty_change_font "$current_font"
  fi
  zle reset-prompt
}

zle -N __kitty_font_changer
bindkey "^g" __kitty_font_changer
