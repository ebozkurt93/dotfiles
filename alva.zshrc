export CDPATH=.:~/:~/repositories
#export XBAR_PLUGINS_PATH='/Users/erdembozkurt/Library/Application Support/xbar/plugins'
#export BITBAR_PLUGINS_PATH='$HOME/Documents/bitbar_plugins'

# Load aliases from .aliases file (.zshrc)
source $HOME/.aliases

# Functions
function mcd
{
  command mkdir $1 && cd $1
}

# Alva related config

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

alias pip=pip3

export PATH=/Applications/Postgres.app/Contents/Versions/10/bin:$PATH
