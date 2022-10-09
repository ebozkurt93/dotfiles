export CDPATH=.:~/
# this one is separated just for brevity
export CDPATH=$CDPATH:~/personal-repositories

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
  # fzf
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# convenience aliases
alias cd..='cd ..'
alias ..='cd ..'
alias cd...='cd ../..'
alias ...='cd ../..'
alias ls='ls -G'
alias l='ls -lF'
alias dir='ls'
alias la='ls -lah'
alias ll='ls -l'
alias vi='nvim'
alias vim='nvim'
alias sr='exec $SHELL'

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
alias mirror='~/Documents/mirror'


# temporary, refetch apartments 
alias apt-refetch='cd ~/personal-repositories/place-scraper-v2 && go run . -s && curl https://apt-api.erdem-bozkurt.com/refetch'


# given a file pattern and commands, this function will rerun commands whenever files change
function res {
  find . -name "$1" | entr -r ${@:2}
}

alias dev-rust='res "*.rs" cargo run'
alias dev-go='res "*.go" go run .'