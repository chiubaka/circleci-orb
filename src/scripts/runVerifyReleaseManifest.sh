#! /usr/bin/env bash
# Validate .releases/<cycle-id>/ trees changed vs primary-branch merge base, or entire directory.
set -euo pipefail

# Resolve merge-base with PRIMARY_BRANCH (same deepen-then-error idea as setTurboScmBase /
# runVerifyChangesets). Echoes the SHA on success; fails with an actionable error otherwise.
_resolve_merge_base() {
  local primary_branch=${PRIMARY_BRANCH:-master}
  local base_ref=$primary_branch

  if ! git rev-parse --verify --quiet "$base_ref" >/dev/null; then
    git fetch origin "$primary_branch":"refs/remotes/origin/$primary_branch" --depth=1 >/dev/null 2>&1 || true
    base_ref="origin/$primary_branch"
  fi

  local merge_base
  merge_base=$(git merge-base HEAD "$base_ref" 2>/dev/null || true)
  if [[ -z "$merge_base" ]]; then
    echo "Shallow history: deepening fetch so merge-base with $primary_branch can be computed" >&2
    git fetch --deepen=4096 origin HEAD 2>/dev/null || true
    git fetch origin "$primary_branch" --deepen=4096 2>/dev/null || true
    if git rev-parse --is-shallow-repository >/dev/null 2>&1 &&
      [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
      git fetch --deepen=200 origin "$primary_branch" >/dev/null 2>&1 ||
        git fetch --unshallow origin "$primary_branch" >/dev/null 2>&1 || true
    fi
    merge_base=$(git merge-base HEAD "$base_ref" 2>/dev/null || true)
  fi

  if [[ -z "$merge_base" ]]; then
    echo "ERROR: could not determine merge-base between HEAD and $base_ref" >&2
    echo "Ensure primary-branch ($primary_branch) exists on origin (chiubaka/setup fetches it)." >&2
    return 1
  fi
  printf '%s\n' "$merge_base"
}

# Paths relative to app root, one .releases/<cycle-id> per line.
list_cycle_paths() {
  local mode=${VERIFY_RELEASE_MANIFEST_MODE:-changed}
  if [[ "$mode" == "all" ]]; then
    find .releases -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort || true
    return 0
  fi

  local merge_base
  if ! merge_base=$(_resolve_merge_base); then
    return 1
  fi

  {
    git diff --name-only "$merge_base" HEAD
    git diff --relative --name-only
    git diff --relative --name-only --cached
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
  local app_dir validator path_list n=0
  local -a paths=()
  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  if ! path_list=$(list_cycle_paths); then
    exit 1
  fi
  mapfile -t paths < <(printf '%s\n' "$path_list" | grep -v '^$' || true)
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
