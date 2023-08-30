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

function is_macos {
  [ "$(uname 2> /dev/null)" = "Darwin" ]
}

if is_macos; then
  source $HOME/.macos.zshrc
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
alias nn='cd ~/Documents; cd `ls | grep Notes`; nvim'

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

# docker-compose
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# tmux
alias t='tmux'

alias yt='docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v "$(pwd)":/workdir:rw mikenye/youtube-dl'
alias ffmpeg='docker run --rm -i -t -v $PWD:/tmp/workdir jrottenberg/ffmpeg'

function __get_pid_for_port() {
  echo "$(lsof -i:$1 -t)"
}

function pk() {
  __get_pid_for_port $1 | xargs kill
}

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
     eval $info[$op-run_cmd] $(echo "$selection" | cut -d'"' -f2)
  fi
  zle send-break
}

zle -N __execute_package_json_command
bindkey "^p" __execute_package_json_command

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

