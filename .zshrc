# Postgres path
export PATH=/Applications/Postgres.app/Contents/Versions/10/bin:$PATH

# Node related stuff
export PATH="/usr/local/opt/node@10/bin:$PATH"
# export PATH="/usr/local/opt/node@12/bin:$PATH"


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc'; fi


# Load aliases from .aliases file (.zshrc)
source $HOME/.aliases

# Functions
function mcd
{
  command mkdir $1 && cd $1
}

