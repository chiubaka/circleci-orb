#! /usr/bin/env bash

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Load new NVM version into current shell
export NVM_DIR="/opt/circleci/.nvm"
# shellcheck disable=1090,1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# shellcheck disable=1090,1091
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
