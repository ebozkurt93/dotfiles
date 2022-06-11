

# Postgres path
export PATH=/Applications/Postgres.app/Contents/Versions/10/bin:$PATH

export CDPATH=.:~/:~/repositories

# Node related stuff
# export PATH="/usr/local/opt/node@10/bin:$PATH"
# export PATH="/usr/local/opt/node@12/bin:$PATH"
export PATH="/usr/local/opt/node@14/bin:$PATH"

# this may be needed in the future for gcloud (running tests fail in pycharm)
# export CLOUDSDK_PYTHON="/System/Library/Frameworks/Python.framework/Versions/2.7/Resources/Python.app/Contents/MacOS/Python"

# Load aliases from .aliases file (.zshrc)
source $HOME/.aliases

# Functions
function mcd
{
  command mkdir $1 && cd $1
}


# added by travis gem
[ ! -s /Users/erdembozkurt/.travis/travis.sh ] || source /Users/erdembozkurt/.travis/travis.sh


eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# BLAS/LAPACK
export OPENBLAS=/usr/local/opt/openblas/lib/

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
# nvm stuff
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

export PATH="/usr/local/opt/openssl@3/bin:$PATH"
