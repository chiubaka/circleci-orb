#! /usr/bin/env bash
# Runs changeset status or a repo-defined verify script. See org ADR 0024–0028.
set -euo pipefail

pnpm_bin=${PNPM_BINARY:-pnpm}
verify_script=${VERIFY_SCRIPT:-}
primary_branch=${PRIMARY_BRANCH:-master}

if [[ -z "$verify_script" ]]; then
  merge_base=$(git merge-base HEAD "$primary_branch" 2>/dev/null || true)
  if [[ -z "$merge_base" ]]; then
    echo "ERROR: could not determine merge-base between HEAD and $primary_branch" >&2
    exit 1
  fi

  has_changeset_markdown_change=false
  while IFS= read -r changed_file; do
    if [[ "$changed_file" == .changeset/*.md ]]; then
      has_changeset_markdown_change=true
      break
    fi
  done < <(git diff --name-only "$merge_base"...HEAD)

  if [[ "$has_changeset_markdown_change" != true ]]; then
    echo "ERROR: this branch must add or modify a .changeset/*.md file" >&2
    echo "No changeset markdown file changes found versus $primary_branch." >&2
    exit 1
  fi

  exec "$pnpm_bin" exec changeset status
fi

exec "$pnpm_bin" run "$verify_script"
