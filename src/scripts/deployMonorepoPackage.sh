#! /usr/bin/env bash
set -e

# shellcheck disable=1090,1091
source "$PARSE_MONOREPO_DEPLOY_TAG_SCRIPT"

package_name="$(parse_package_name "$CIRCLE_TAG")"

yarn=${YARN_BINARY:-"yarn"}

if [ "$DRY_RUN" = true ]; then
  $yarn deploy:ci "$package_name" --dry-run
else
  $yarn deploy:ci "$package_name"
fi
