#! /usr/bin/env bash

npmrc_path=${NPMRC_PATH:-~/.npmrc}

echo "//registry.yarnpkg.com/:_authToken=${NPM_TOKEN}" >> "$npmrc_path"
