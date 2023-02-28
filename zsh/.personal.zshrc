export PATH=$PATH:~/bin
export GH_USERNAME=ebozkurt93
# Functions
function mcd
{
  command mkdir -p $1 && cd $1
}

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
alias dsync='echo "$(cd ~/dotfiles/ && git pull && cd ~/dotfiles/scripts && ./stow.sh)"'
alias sr='exec $SHELL'
alias ss='echo $__sourced_states'
local function __state_switcher_toggle() {
  local p=~/Documents/bitbar_plugins/state-switcher.5m.sh
  local selected_state=$($p states | tr ' ' '\n' | sort | fzf)
  test -z $selected_state && return
  $p toggle $selected_state
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
alias db='docker build -t'
# remove all stopped docker containers
alias drm="d ps -a | grep Exited | awk '{print $1}' | tr '\n' ' ' | xargs docker rm"
alias d-restart="osascript -e 'quit app \"Docker\"'; sleep 1; open --background -a Docker && while ! docker system info > /dev/null 2>&1; do sleep 1; done"
alias d-start="open /Applications/Docker.app"
alias d-stop="docker system info > /dev/null 2>&1 && ( {osascript -e 'quit app \"Docker\"'} &)"
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
  find /var/folders -name '*nvim*' 2>/dev/null | tail -n +2 | xargs -I {} nvim --server {} --remote-send "$1"
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
  selected_dir="$(cat <(echo ~/dotfiles) <(test ${#p[@]} -ne 0 && find ${p[@]} -maxdepth 1 -type d 2>/dev/null) | sort | uniq | fzf)"
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
eval "$(starship init zsh)"

function __theme_helper() {
  local themes=(
  'gruvbox-dark' 'gruvbox-light'
  'rose-pine' 'rose-pine-moon-dark' 'rose-pine-dawn-light'
  'mellow' 'ayu-dark' 'ayu-light' 'everforest-dark' 'oxocarbon' 'tokyonight-storm'
  'oh-lucy' 'oh-lucy-evening' 'nord'
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
  local nvim_themefile=~/.config/nvim/lua/ebozkurt/themes.lua
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

function __yarn_execute_package_json_command() {
  if [[ ! -f  "package.json" ]]; then
    # this is the default behaviour for zsh in ctrl-p, so doing that in default case
    zle up-history
    return
  fi
  local selection=$(cat package.json | jq  '.scripts' | sed -e '1d' -e '$d' | \
    fzf --bind 'ctrl-p:execute(echo _{})+abort')
  [[ -z $selection ]] && return
  if [[ $selection =~ ^_.* ]]; then
    cmd=$(echo "yarn $(echo "$selection" | cut -c2- | cut -d'"' -f2)")
    echo $cmd | pbcopy
    echo "Copied command ($cmd) to clipboard"
  else
    yarn $(echo "$selection" | cut -d'"' -f2)
  fi
  zle send-break
}

zle -N __yarn_execute_package_json_command
bindkey "^p" __yarn_execute_package_json_command

function __bt_device_toggle() {
  if [[ "$(blueutil --power)" == "0" ]]; then
    echo 'bluetooth off'
    zle send-break
    return
  fi
  local c=$(blueutil --paired --format json | jq -r \
    '.[] | .name + " " + (.connected|tostring|sub("true"; "✅")|sub("false"; "❌")) + " " + .address')
  local selection=$(echo "$c" | sort | fzf)
  [[ -z $selection ]] && return
  address=$(echo $selection | awk '{print $NF}')
  if [[ "$(blueutil --is-connected $address)" == '1' ]]; then
    blueutil --disconnect $address --wait-disconnect $address
  else
    blueutil --connect $address
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

