#! /usr/bin/env bash

npmrc_path="${NPMRC_PATH:-"~/.npmrc"}"

echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> "$npmrc_path"
