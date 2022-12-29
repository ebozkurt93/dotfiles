# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc'; fi

alias gclog='gcloud auth login erdem@bemlo.se'
export CLOUDSDK_ACTIVE_CONFIG_NAME='bemlo'

if [ "$(uname 2> /dev/null)" = "Darwin" ]; then
  . ~/.asdf/plugins/java/set-java-home.zsh
fi

alias tsr="nvim_remote_exec \"<cmd>:LspRestart tsserver<cr>\""
alias pres="__get_pid_for_port 8085 | xargs kill"
alias fres="__get_pid_for_port 8080 | xargs kill"

function dres() {
  pres
  fres
}

function __yarn_execute_package_json_command() {
  [[ ! -f  "package.json" ]] && return
  local selection=$(cat package.json | jq  '.scripts' | sed -e '1d' -e '$d' | fzf)
  if [[ ! -z $selection ]]; then
    yarn $(echo "$selection" | cut -d'"' -f2)
    zle send-break
  fi
}
zle -N __yarn_execute_package_json_command
bindkey "^p" __yarn_execute_package_json_command
