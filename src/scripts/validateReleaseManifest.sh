#! /usr/bin/env bash
# Validate a pin-only .releases manifest via validateReleaseManifest.mjs (ADR 0038).
set -euo pipefail

_resolve_validator_script() {
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
  echo "validateReleaseManifest: set VALIDATE_RELEASE_MANIFEST_SCRIPT or keep validateReleaseManifest.mjs next to this script." >&2
  return 1
}

run_validate_release_manifest() {
  local validator manifest_path
  if ! validator=$(_resolve_validator_script); then
    return 1
  fi
  manifest_path=${1:-${RELEASE_MANIFEST_PATH:-}}
  if [[ -z "$manifest_path" ]]; then
    echo "validateReleaseManifest: manifest path argument or RELEASE_MANIFEST_PATH required." >&2
    return 1
  fi
  # shellcheck disable=SC2046
  eval "$(node "$validator" "$manifest_path")"
  export RELEASE_MANIFEST_PATH RELEASE_ID ARTIFACTS_JSON
}

if [[ "${VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY:-}" != "true" ]]; then
  run_validate_release_manifest "$@"
fi
