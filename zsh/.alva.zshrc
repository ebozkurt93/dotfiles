export CDPATH=$CDPATH:~/repositories

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc'; fi


export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PATH"
#export PATH="$(pyenv root)/libexec/pyenv:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi


export NVM_DIR="$HOME/.nvm"
    [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh" # This loads nvm
    [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

export PATH="/usr/local/opt/node@14/bin:$PATH"

export PATH="/opt/homebrew/opt/openssl@3/bin:$PATH /opt/homebrew/opt/libpq/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/libpq/include"

export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=true
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=true

# this was not in our config, but seems to fix some errors that pop up
# https://github.com/ray-project/ray/issues/24917#issuecomment-1131190980
# export GRPC_ENABLE_FORK_SUPPORT=0

#alias pip=pip3

ulimit -n 10256222

export PATH=/Applications/Postgres.app/Contents/Versions/10/bin:$PATH

# this can be needed when installing different terraform versions
# export TFENV_ARCH=amd64

alias pycharm='open -a /Applications/PyCharm.app'
## get schema and run frontend
alias frr='yarn run get-schema; yarn run generate-typescript-types; yarn run start'
alias sfrr='export VITE_NO_LOCAL_BACKEND=true && yarn run get-schema-staging && yarn run generate-typescript-types && yarn start'

alias pip-upgrade='pip install --upgrade pip'
function __reset_alva_pubsub_container {
  docker ps -a | grep eu.gcr.io/alva-backend/pubsub:latest | awk '{print $1}' | tr '\n' ' ' | xargs docker rm -f
  docker run -d --restart always -p 8085:8085 eu.gcr.io/alva-backend/pubsub:latest
}
alias drs="__reset_alva_pubsub_container"
