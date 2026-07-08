#! /usr/bin/env bash
# Coordinated deploy at promotion tag commit (commit-primary; manifest pins for audit — ADR 0042).
set -euo pipefail

parse_promotion_tag_main() {
  local tag raw env rest rc_index=""
  raw=${CIRCLE_TAG:-${TAG:-}}
  if [[ -z "$raw" ]]; then
    echo "parsePromotionTag: CIRCLE_TAG or TAG must be set." >&2
    exit 1
  fi
  tag=${raw#v}

  if [[ "$tag" =~ ^staging-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)-rc([0-9]+)$ ]]; then
    env=staging
    rest="${BASH_REMATCH[1]}"
    rc_index="${BASH_REMATCH[2]}"
  elif [[ "$tag" =~ ^prod-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)$ ]]; then
    env=prod
    rest="${BASH_REMATCH[1]}"
  else
    echo "parsePromotionTag: tag must match staging-<cycle-id>-rc<n> or prod-<cycle-id> (got: ${tag})." >&2
    echo "  See ADR 0031 and ADR 0042 for promotion tag conventions." >&2
    exit 1
  fi

  export PROMOTION_ENV="$env"
  export RELEASE_ID="$rest"
  export RC_INDEX="$rc_index"
  printf 'PROMOTION_ENV=%s\n' "$PROMOTION_ENV"
  printf 'RELEASE_ID=%s\n' "$RELEASE_ID"
  if [[ -n "$rc_index" ]]; then
    printf 'RC_INDEX=%s\n' "$RC_INDEX"
  fi
}

_resolve_manifest_validator_script() {
  if [[ -n "${VALIDATE_RELEASE_MANIFEST_SCRIPT:-}" && -f "${VALIDATE_RELEASE_MANIFEST_SCRIPT}" ]]; then
    printf '%s\n' "$VALIDATE_RELEASE_MANIFEST_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/validateReleaseManifest.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runCoordinatedDeploy: set VALIDATE_RELEASE_MANIFEST_SCRIPT or keep validateReleaseManifest.mjs next to this script." >&2
  return 1
}

run_validate_release_manifest() {
  local validator manifest_path validator_output line key value
  if ! validator=$(_resolve_manifest_validator_script); then
    return 1
  fi
  manifest_path=${1:-${RELEASE_MANIFEST_PATH:-}}
  if [[ -z "$manifest_path" ]]; then
    echo "runCoordinatedDeploy: manifest path argument or RELEASE_MANIFEST_PATH required." >&2
    return 1
  fi
  # Capture output and check node's exit status explicitly; process substitution would
  # swallow validator failures and let an invalid manifest report success.
  if ! validator_output=$(node "$validator" "$manifest_path"); then
    echo "runCoordinatedDeploy: manifest validation failed for ${manifest_path}." >&2
    return 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      RELEASE_MANIFEST_PATH | RELEASE_ID | RC_INDEX | ARTIFACTS_JSON)
        export "${key}=${value}"
        ;;
      *)
        echo "runCoordinatedDeploy: unexpected validator output (expected KEY=VALUE)." >&2
        return 1
        ;;
    esac
  done <<<"$validator_output"
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
  local app_dir manifest_path deploy_script dry_raw dry_lower releases_dir rc_index
  local skip_raw skip_lower pnpm_bin

  app_dir=${APP_DIR:-.}
  cd "$app_dir"

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
    run_validate_release_manifest "$manifest_path"
    export RELEASE_MANIFEST_PATH RELEASE_ID RC_INDEX ARTIFACTS_JSON
  else
    if [[ -n "$manifest_path" && -f "$manifest_path" ]]; then
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
