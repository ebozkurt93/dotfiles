export PATH=$PATH:~/Documents/binaries
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
alias sr='exec $SHELL'
local function __state_switcher_toggle() {
  local p=~/Documents/bitbar_plugins/state-switcher.5m.sh
  selected_state=$($p states | tr ' ' '\n' | sort | fzf)
  if [[ ! -z $selected_state ]]; then
    $p toggle $selected_state
  fi
}
alias st="__state_switcher_toggle"

# docker
alias d='docker'
alias dr='docker run --rm -i -t'
alias dx='docker exec -i -t'
alias db='docker build -t'
# remove all stopped docker containers
alias drm="d ps -a | grep Exited | awk '{print $1}' | tr '\n' ' ' | xargs docker rm"

# docker-compose
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# tmux
alias t='tmux'

alias cat='bat --paging=never'

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


# given a file pattern and commands, this function will rerun commands whenever files change
function res {
  find . -name "$1" | entr -r ${@:2}
}

function __find_repos {
  local p=(~/repositories)
  if [ -f ~/Documents/bitbar_plugins/tmp/personal ]; then
    p+=(~/personal-repositories)
  fi
  cd $(cat <(echo ~/dotfiles) <(find ${p[@]} -maxdepth 1 -type d) | sort | fzf)
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

function __change_theme() {
  themes=('gruvbox-dark' 'rose-pine-moon-dark' 'rose-pine-dawn-light' 'mellow' 'ayu-dark' 'ayu-light')
  selected_theme=$(echo ${themes[@]} | tr ' ' '\n' | sort | fzf)
  test -z $selected_theme && return
  echo Selected $selected_theme
  kitty_conf=~/.config/kitty
  nvim_themefile=~/.config/nvim/lua/ebozkurt/themes.lua
  cp $kitty_conf/themes/$selected_theme.conf $kitty_conf/current-theme.conf
  sed -i '' "1s/.*/local selected_theme = \'$selected_theme\'/" $nvim_themefile
  zle reset-prompt
}

zle -N __change_theme
# alt t
bindkey "^[t" __change_theme
bindkey "^k" clear-screen

