# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc'; fi

alias gclog='gcloud auth login erdem@bemlo.se'
export CLOUDSDK_ACTIVE_CONFIG_NAME='bemlo'

if [ "$(uname 2> /dev/null)" = "Darwin" ]; then
  . ~/.asdf/plugins/java/set-java-home.zsh
fi
