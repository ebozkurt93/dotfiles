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
alias lres="nvim_remote_exec \"<cmd>:LspStop<cr>\" && sleep 1 && nvim_remote_exec \"<cmd>:LspStart<cr>\""
alias pres="__get_pid_for_port 8085 | xargs kill"
alias fres="__get_pid_for_port 8080 | xargs kill"
alias ytf="resr '**.spec.ts' 'yarn jest \$0'"
alias yta="res '**.ts' yarn test"

function dres() {
  pres
  fres
}

function __copy_user_email() {
  local selection=$(cat ~/Documents/bitbar_plugins/tmp/bemlo_local_auth_users.txt | sort | fzf)
  [[ -z $selection ]] && return
  echo $selection | pbcopy
  echo "Copied selection ($selection) to clipboard"
  zle send-break
}

zle -N __copy_user_email 
bindkey "^u" __copy_user_email 
