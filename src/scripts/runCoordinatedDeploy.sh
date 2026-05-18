#! /usr/bin/env bash
# Coordinated deploy at promotion tag commit (commit-primary; manifest pins for audit — ADR 0038).
set -euo pipefail

_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd
}

run_coordinated_deploy_main() {
  local app_dir manifest_path deploy_script dry_raw dry_lower releases_dir script_dir
  local skip_raw skip_lower pnpm_bin
  script_dir=$(_script_dir)

  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  # shellcheck disable=SC2034
  PARSE_PROMOTION_TAG_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "${script_dir}/parsePromotionTag.sh"
  parse_promotion_tag_main

  skip_raw=${SKIP_MANIFEST_VALIDATION:-false}
  skip_lower=$(printf '%s' "$skip_raw" | tr '[:upper:]' '[:lower:]')
  if [[ "$skip_lower" != "true" ]] && [[ "$skip_lower" != "1" ]]; then
    releases_dir=${RELEASES_DIR:-.releases}
    manifest_path=${MANIFEST_PATH:-${releases_dir}/${RELEASE_ID}.yml}
    if [[ ! -f "$manifest_path" ]]; then
      echo "runCoordinatedDeploy: manifest not found at ${manifest_path}." >&2
      exit 1
    fi
    # shellcheck disable=SC2034
    VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY=true
    # shellcheck disable=SC1091
    source "${script_dir}/validateReleaseManifest.sh"
    run_validate_release_manifest "$manifest_path"
    export RELEASE_MANIFEST_PATH RELEASE_ID ARTIFACTS_JSON
  else
    manifest_path=${MANIFEST_PATH:-${RELEASE_MANIFEST_PATH:-}}
    if [[ -n "$manifest_path" && -f "$manifest_path" ]]; then
      # shellcheck disable=SC2034
      VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY=true
      # shellcheck disable=SC1091
      source "${script_dir}/validateReleaseManifest.sh"
      run_validate_release_manifest "$manifest_path"
      export RELEASE_MANIFEST_PATH RELEASE_ID ARTIFACTS_JSON
    fi
  fi

  deploy_script=${DEPLOY_SCRIPT:-}
  if [[ -z "$deploy_script" ]]; then
    echo "runCoordinatedDeploy: set deploy-script parameter (package.json script name, e.g. deploy:coordinated)." >&2
    exit 1
  fi

  dry_raw=${DRY_RUN:-false}
  dry_lower=$(printf '%s' "$dry_raw" | tr '[:upper:]' '[:lower:]')
  export RELEASE_MANIFEST_PATH=${RELEASE_MANIFEST_PATH:-$manifest_path}
  export PROMOTION_ENV RELEASE_ID ARTIFACTS_JSON

  pnpm_bin=${PNPM_BINARY:-pnpm}
  if [[ "$dry_lower" == "true" ]] || [[ "$dry_lower" == "1" ]]; then
    exec "$pnpm_bin" run "$deploy_script" -- --dry-run
  fi
  exec "$pnpm_bin" run "$deploy_script"
}

if [[ "${COORDINATED_DEPLOY_SOURCE_ONLY:-}" != "true" ]]; then
  run_coordinated_deploy_main "$@"
fi
