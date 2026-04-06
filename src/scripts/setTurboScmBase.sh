#! /usr/bin/env bash

if [ "$CIRCLE_BRANCH" = "$PRIMARY_BRANCH" ]; then
  echo "On primary branch, skipping TURBO_SCM_BASE setup"
  exit 0
fi

git fetch origin "$PRIMARY_BRANCH":"$PRIMARY_BRANCH" --depth=1

turbo_scm_base=$(git merge-base HEAD "$PRIMARY_BRANCH" 2>/dev/null || true)
if [ -z "$turbo_scm_base" ]; then
  echo "Shallow history: deepening fetch so merge-base with $PRIMARY_BRANCH can be computed"
  git fetch --deepen=4096 origin HEAD 2>/dev/null || true
  git fetch origin "$PRIMARY_BRANCH" --deepen=4096 2>/dev/null || true
  turbo_scm_base=$(git merge-base HEAD "$PRIMARY_BRANCH" 2>/dev/null || true)
fi
if [ -z "$turbo_scm_base" ]; then
  echo "ERROR: could not determine merge-base between HEAD and $PRIMARY_BRANCH" >&2
  exit 1
fi

echo "export TURBO_SCM_BASE=$turbo_scm_base" >> "$BASH_ENV"
echo "Setting TURBO_SCM_BASE=$turbo_scm_base"
