#! /usr/bin/env bash
# Validate .releases/*.yml changed in working tree or entire directory (PR checks).
set -euo pipefail

list_manifest_paths() {
  local mode=${VERIFY_RELEASE_MANIFEST_MODE:-changed}
  if [[ "$mode" == "all" ]]; then
    find .releases -maxdepth 1 -name '*.yml' -type f 2>/dev/null | LC_ALL=C sort || true
    return
  fi
  {
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | grep -E '^\.releases/[^/]+\.yml$' | LC_ALL=C sort -u || true
}

run_verify_release_manifest_main() {
  local app_dir validator paths path n=0
  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  # shellcheck disable=SC3028
  validator="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/validateReleaseManifest.mjs"
  if [[ ! -f "$validator" ]]; then
    echo "runVerifyReleaseManifest: validateReleaseManifest.mjs not found." >&2
    exit 1
  fi

  mapfile -t paths < <(list_manifest_paths | grep -v '^$' || true)
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "runVerifyReleaseManifest: no .releases/*.yml to validate; skipping."
    exit 0
  fi

  for path in "${paths[@]}"; do
    node "$validator" "$path"
    n=$((n + 1))
  done
  echo "runVerifyReleaseManifest: validated ${n} manifest(s)."
}

if [[ "${VERIFY_RELEASE_MANIFEST_SOURCE_ONLY:-}" != "true" ]]; then
  run_verify_release_manifest_main "$@"
fi
