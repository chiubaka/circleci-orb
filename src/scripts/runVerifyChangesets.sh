#! /usr/bin/env bash
# Runs changeset status or a repo-defined verify script. See org ADR 0024–0028.
set -euo pipefail

pnpm_bin=${PNPM_BINARY:-pnpm}
verify_script=${VERIFY_SCRIPT:-}
primary_branch=${PRIMARY_BRANCH:-master}
base_ref=$primary_branch

_resolve_category_prefix_verifier() {
  if [[ -n "${VERIFY_CHANGESET_CATEGORY_PREFIXES_SCRIPT:-}" && -f "${VERIFY_CHANGESET_CATEGORY_PREFIXES_SCRIPT}" ]]; then
    printf '%s\n' "$VERIFY_CHANGESET_CATEGORY_PREFIXES_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/verifyChangesetCategoryPrefixes.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runVerifyChangesets: set VERIFY_CHANGESET_CATEGORY_PREFIXES_SCRIPT or keep verifyChangesetCategoryPrefixes.mjs next to this script." >&2
  return 1
}

list_changed_changeset_markdown_paths() {
  local merge_base=$1
  while IFS=$'\t' read -r status changed_file renamed_file; do
    candidate_path=${renamed_file:-$changed_file}
    case "$status" in
      A*|M*|R*|C*) ;;
      *) continue ;;
    esac
    if [[ "$candidate_path" == .changeset/*.md ]]; then
      basename=${candidate_path##*/}
      [[ "$(printf '%s' "$basename" | tr '[:upper:]' '[:lower:]')" == "readme.md" ]] && continue
      printf '%s\n' "$candidate_path"
    fi
  done < <(git diff --name-status "$merge_base"...HEAD)
}

verify_changeset_category_prefixes() {
  local merge_base=$1 require_lower verifier
  require_lower=$(printf '%s' "${REQUIRE_CHANGESET_CATEGORY_PREFIX:-false}" | tr '[:upper:]' '[:lower:]')
  if [[ "$require_lower" != "true" && "$require_lower" != "1" ]]; then
    return 0
  fi
  if ! verifier=$(_resolve_category_prefix_verifier); then
    return 1
  fi
  local -a paths=()
  mapfile -t paths < <(list_changed_changeset_markdown_paths "$merge_base" | grep -v '^$' || true)
  if [[ ${#paths[@]} -eq 0 ]]; then
    return 0
  fi
  node "$verifier" "${paths[@]}"
}

require_prefix_lower=$(printf '%s' "${REQUIRE_CHANGESET_CATEGORY_PREFIX:-false}" | tr '[:upper:]' '[:lower:]')
need_merge_base=false
if [[ "$require_prefix_lower" == "true" || "$require_prefix_lower" == "1" ]]; then
  need_merge_base=true
fi
if [[ -z "$verify_script" ]]; then
  need_merge_base=true
fi

merge_base=""
if [[ "$need_merge_base" == true ]]; then
  if ! git rev-parse --verify --quiet "$base_ref" >/dev/null; then
    git fetch origin "$primary_branch":"refs/remotes/origin/$primary_branch" --depth=1 >/dev/null 2>&1 || true
    base_ref="origin/$primary_branch"
  fi

  merge_base=$(git merge-base HEAD "$base_ref" 2>/dev/null || true)
  if [[ -z "$merge_base" ]] && git rev-parse --is-shallow-repository >/dev/null 2>&1 && [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
    git fetch --deepen=200 origin "$primary_branch" >/dev/null 2>&1 || git fetch --unshallow origin "$primary_branch" >/dev/null 2>&1 || true
    merge_base=$(git merge-base HEAD "$base_ref" 2>/dev/null || true)
  fi

  if [[ -z "$merge_base" ]]; then
    echo "ERROR: could not determine merge-base between HEAD and $base_ref" >&2
    exit 1
  fi
fi

verify_changeset_category_prefixes "$merge_base"

if [[ -z "$verify_script" ]]; then
  has_changeset_markdown_change=false
  while IFS=$'\t' read -r status changed_file renamed_file; do
    candidate_path=${renamed_file:-$changed_file}
    case "$status" in
      A*|M*|R*|C*) ;;
      *) continue ;;
    esac
    if [[ "$candidate_path" == .changeset/*.md ]]; then
      has_changeset_markdown_change=true
      break
    fi
  done < <(git diff --name-status "$merge_base"...HEAD)

  if [[ "$has_changeset_markdown_change" != true ]]; then
    echo "ERROR: this branch must add or modify a .changeset/*.md file" >&2
    echo "No changeset markdown file changes found versus $primary_branch." >&2
    exit 1
  fi

  exec "$pnpm_bin" exec changeset status
fi

exec "$pnpm_bin" run "$verify_script"
