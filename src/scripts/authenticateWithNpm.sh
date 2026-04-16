#! /usr/bin/env bash
# Deprecated: prefer setupNpmRegistryAuth.sh (REGISTRY_BACKEND=npmjs) or the
# setup-npm-registry-auth orb command. This file remains self-contained so
# << include(scripts/authenticateWithNpm.sh) >> in consumer configs keeps working
# (CircleCI inlines the script body; sibling-path exec would not).
set -euo pipefail

npmrc_path=${NPMRC_PATH:-"$HOME/.npmrc"}
if [[ "${npmrc_path:0:1}" == '~' ]]; then
  npmrc_path="${npmrc_path/#\~/$HOME}"
fi

if [[ -z "${NPM_TOKEN:-}" ]]; then
  echo "authenticateWithNpm: NPM_TOKEN must be set." >&2
  exit 1
fi

echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >>"$npmrc_path"
