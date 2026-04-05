#! /usr/bin/env bash

if [ "$CIRCLE_BRANCH" = "$PRIMARY_BRANCH" ]; then
  echo "On primary branch, skipping TURBO_SCM_BASE setup"
  exit 0
fi

git fetch origin "$PRIMARY_BRANCH":"$PRIMARY_BRANCH" --depth=1

turbo_scm_base=$(git merge-base HEAD "$PRIMARY_BRANCH")

echo "export TURBO_SCM_BASE=$turbo_scm_base" >> "$BASH_ENV"
echo "Setting TURBO_SCM_BASE=$turbo_scm_base"
