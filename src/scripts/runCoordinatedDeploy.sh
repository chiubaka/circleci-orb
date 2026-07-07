#! /usr/bin/env bash
# Coordinated deploy at promotion tag commit (commit-primary; manifest pins for audit — ADR 0042).
set -euo pipefail

_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd
}

resolve_highest_rc_index() {
  local releases_dir=$1 cycle_id=$2 rc_dir n max=0
  shopt -s nullglob
  for rc_dir in "${releases_dir}/${cycle_id}"/rc*/; do
    n=$(basename "$rc_dir")
    n=${n#rc}
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n > max )); then
      max=$n
    fi
  done
  shopt -u nullglob 2>/dev/null || true
  printf '%s' "$max"
}

run_coordinated_deploy_main() {
  local app_dir manifest_path deploy_script dry_raw dry_lower releases_dir script_dir rc_index
  local skip_raw skip_lower pnpm_bin
  script_dir=$(_script_dir)

  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  # shellcheck disable=SC2034
  PARSE_PROMOTION_TAG_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "${script_dir}/parsePromotionTag.sh"
  parse_promotion_tag_main

  releases_dir=${RELEASES_DIR:-.releases}
  if [[ "$PROMOTION_ENV" == "staging" ]]; then
    if [[ -z "${RC_INDEX:-}" ]]; then
      echo "runCoordinatedDeploy: staging promotion tag must include -rc<n>." >&2
      exit 1
    fi
    rc_index=$RC_INDEX
  else
    rc_index=$(resolve_highest_rc_index "$releases_dir" "$RELEASE_ID")
    if [[ -z "$rc_index" || "$rc_index" -lt 1 ]]; then
      echo "runCoordinatedDeploy: no rc*/manifest.yml found for cycle ${RELEASE_ID}." >&2
      exit 1
    fi
  fi

  skip_raw=${SKIP_MANIFEST_VALIDATION:-false}
  skip_lower=$(printf '%s' "$skip_raw" | tr '[:upper:]' '[:lower:]')
  manifest_path=${MANIFEST_PATH:-${releases_dir}/${RELEASE_ID}/rc${rc_index}/manifest.yml}

  if [[ "$skip_lower" != "true" ]] && [[ "$skip_lower" != "1" ]]; then
    if [[ ! -f "$manifest_path" ]]; then
      echo "runCoordinatedDeploy: manifest not found at ${manifest_path}." >&2
      exit 1
    fi
    # shellcheck disable=SC2034
    VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY=true
    # shellcheck disable=SC1091
    source "${script_dir}/validateReleaseManifest.sh"
    run_validate_release_manifest "$manifest_path"
    export RELEASE_MANIFEST_PATH RELEASE_ID RC_INDEX ARTIFACTS_JSON
  else
    if [[ -n "$manifest_path" && -f "$manifest_path" ]]; then
      # shellcheck disable=SC2034
      VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY=true
      # shellcheck disable=SC1091
      source "${script_dir}/validateReleaseManifest.sh"
      run_validate_release_manifest "$manifest_path"
      export RELEASE_MANIFEST_PATH RELEASE_ID RC_INDEX ARTIFACTS_JSON
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
  export RC_INDEX=${RC_INDEX:-$rc_index}
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
