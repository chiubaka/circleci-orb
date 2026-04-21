#! /usr/bin/env bash
# Runs changeset status or a repo-defined verify script. See org ADR 0024–0028.
set -euo pipefail

pnpm_bin=${PNPM_BINARY:-pnpm}
verify_script=${VERIFY_SCRIPT:-}
primary_branch=${PRIMARY_BRANCH:-master}
base_ref=$primary_branch

if [[ -z "$verify_script" ]]; then
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
