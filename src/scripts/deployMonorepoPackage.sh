#! /usr/bin/env bash
set -e

# shellcheck disable=1090,1091
source "$PARSE_MONOREPO_DEPLOY_TAG_SCRIPT"

package_name="$(parse_package_name "$CIRCLE_TAG")"

pnpm_bin=${PNPM_BINARY:-"pnpm"}
deploy_script=${DEPLOY_SCRIPT:-"deploy:ci"}

if [ "$DRY_RUN" = true ]; then
  $pnpm_bin "$deploy_script" "$package_name" --dry-run
else
  $pnpm_bin "$deploy_script" "$package_name"
fi
