export CDPATH=.:~/:~/repositories

# Load aliases from .aliases file (.zshrc)
source $HOME/.aliases

# Functions
function mcd
{
  command mkdir $1 && cd $1
}
