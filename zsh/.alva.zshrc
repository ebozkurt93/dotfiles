# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/erdembozkurt/google-cloud-sdk/completion.zsh.inc'; fi

alias gclog='gcloud auth login erdem@alvalabs.io'
export CLOUDSDK_ACTIVE_CONFIG_NAME='alva'

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
# get schema and run frontend
function fr {
	typeset -A repos
	local repos=(
		['admin']='yarn run get-schema-local; yarn run generate-typescript-types; yarn run start'
		['alva-app']='yarn run get-schema-local; yarn run generate-typescript-types; yarn run start'
		['apollo-federation-gateway']='yarn start:dev'
		['logic-test-management-gui']='yarn --cwd frontend start'
		['personality-test-management']='yarn --cwd frontend start'
)
	b="$(basename $PWD)"
	if [[ ! -z $repos[$b] ]]; then
		eval " $repos[$b]"
	else
		yarn run start
	fi
}
# run alva-app using staging as backend
alias sfr='export VITE_NO_LOCAL_BACKEND=true && yarn run get-schema-staging && yarn run generate-typescript-types && yarn start'

alias pr='pipenv run python run.py'
alias pip-upgrade='pip install --upgrade pip'
function __reset_alva_pubsub_container {
  docker ps -a | grep eu.gcr.io/alva-backend/pubsub:latest | awk '{print $1}' | tr '\n' ' ' | xargs docker rm -f
  # docker ps -a | grep eu.gcr.io/alva-backend/firestore:latest | awk '{print $1}' | tr '\n' ' ' | xargs docker stop | xargs docker rm -f
  docker run -d --restart always -p 8085:8085 eu.gcr.io/alva-backend/pubsub:latest
  # docker run -d --restart always -p 8080:8080 -p 4001:4000 -v firestore-data:/data eu.gcr.io/alva-backend/firestore:latest
}
alias drs="__reset_alva_pubsub_container"
alias ds="~/Documents/bitbar_plugins/open-repo.5m.sh start-pg-d"
alias dk="~/Documents/bitbar_plugins/open-repo.5m.sh kill-pg-d"

function __run_plantuml_server {
  docker run -d -p 8180:8080 plantuml/plantuml-server:jetty
}
