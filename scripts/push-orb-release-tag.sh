#!/usr/bin/env bash
# Push annotated semver tag v<package.json version> for CircleCI orb-tools production publish.
# Idempotent when the tag already exists on origin. Uses GITHUB_TOKEN in the remote URL when set.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

version=$(jq -r '.version // empty' package.json)
if [[ -z "$version" ]]; then
  echo "push-orb-release-tag: package.json missing .version" >&2
  exit 1
fi

tag="v${version}"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  host="${CIRCLE_PROJECT_USERNAME:-}"
  repo="${CIRCLE_PROJECT_REPONAME:-}"
  if [[ -n "$host" && -n "$repo" ]]; then
    git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${host}/${repo}.git"
  fi
fi

if git ls-remote --tags origin "refs/tags/${tag}" | grep -q .; then
  echo "Tag ${tag} already exists on origin; nothing to do."
  exit 0
fi

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag ${tag} exists locally; pushing."
  git push origin "refs/tags/${tag}"
  exit 0
fi

git tag -a "$tag" -m "chore(release): ${tag}"
git push origin "refs/tags/${tag}"
echo "Pushed ${tag}"
