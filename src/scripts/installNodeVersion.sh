#! /usr/bin/env bash
set -e

nvm install $NODE_VERSION
nvm alias default $NODE_VERSION
