#! /usr/bin/env bash
# Validate .releases/<cycle-id>/ trees changed in working tree or entire directory (PR checks).
set -euo pipefail

list_cycle_paths() {
  local mode=${VERIFY_RELEASE_MANIFEST_MODE:-changed}
  if [[ "$mode" == "all" ]]; then
    find .releases -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort || true
    return
  fi
  {
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | grep -E '^\.releases/[^/]+/' | sed -E 's#^(\.releases/[^/]+)/.*#\1#' | LC_ALL=C sort -u || true
}

_resolve_cycle_validator_script() {
  if [[ -n "${VALIDATE_RELEASE_CYCLE_SCRIPT:-}" && -f "${VALIDATE_RELEASE_CYCLE_SCRIPT}" ]]; then
    printf '%s\n' "$VALIDATE_RELEASE_CYCLE_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/validateReleaseCycle.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runVerifyReleaseManifest: set VALIDATE_RELEASE_CYCLE_SCRIPT or keep validateReleaseCycle.mjs next to this script." >&2
  return 1
}

run_verify_release_manifest_main() {
  local app_dir validator paths path n=0
  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  mapfile -t paths < <(list_cycle_paths | grep -v '^$' || true)
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "runVerifyReleaseManifest: no .releases/<cycle-id>/ trees to validate; skipping."
    exit 0
  fi

  if ! validator=$(_resolve_cycle_validator_script); then
    exit 1
  fi

  for path in "${paths[@]}"; do
    node "$validator" "$path"
    n=$((n + 1))
  done
  echo "runVerifyReleaseManifest: validated ${n} release cycle(s)."
}

if [[ "${VERIFY_RELEASE_MANIFEST_SOURCE_ONLY:-}" != "true" ]]; then
  run_verify_release_manifest_main "$@"
fi
