#! /usr/bin/env bash
# Pending changesets -> changeset version -> commit on release/<primary> -> gh PR. Requires GITHUB_TOKEN, gh, git push.
set -euo pipefail

count_pending_changesets() {
  local n=0 f nullglob_restore
  nullglob_restore=$(shopt -p nullglob)
  shopt -s nullglob
  for f in .changeset/*.md; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "README.md" ]] && continue
    n=$((n + 1))
  done
  eval "$nullglob_restore"
  printf '%s' "$n"
}

pkg_at_version() {
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const j = JSON.parse(fs.readFileSync(p, "utf8"));
    if (j.name && j.version) process.stdout.write(j.name + "@" + j.version);
  ' "$1" 2>/dev/null || true
}

build_title() {
  local -a lines=()
  local f line
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$f" ]] || continue
    line=$(pkg_at_version "$f")
    [[ -n "$line" ]] || continue
    lines+=("$line")
  done < <(git diff --name-only | grep -E '(^|/)package\.json$' || true)
  if [[ ${#lines[@]} -eq 0 ]]; then
    return 1
  fi
  mapfile -t lines < <(printf '%s\n' "${lines[@]}" | LC_ALL=C sort -u)
  local joined
  joined=$(printf '%s, ' "${lines[@]}")
  joined=${joined%, }
  printf '%s' "chore(release): version packages (${joined})"
  return 0
}

extract_changelog_top() {
  local file=$1
  [[ -f "$file" ]] || return 0
  awk '
    /^## [0-9]/ { if (++s == 1) next; if (s > 1) exit }
    s == 1 { print }
  ' "$file"
}

build_pr_body_file() {
  local out=$1
  {
    echo "## Changelog excerpts"
    echo
    echo "Automated version bump via Changesets (release PR)."
    echo
  } >"$out"

  while IFS= read -r cl; do
    [[ -n "$cl" ]] || continue
    [[ -f "$cl" ]] || continue
    local pkg_json dir name=""
    dir=$(dirname "$cl")
    pkg_json="${dir}/package.json"
    if [[ -f "$pkg_json" ]]; then
      name=$(node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(j.name||"")' "$pkg_json" 2>/dev/null || true)
    fi
    [[ -n "$name" ]] || name="$cl"
    local excerpt
    excerpt=$(extract_changelog_top "$cl" | head -n 200 || true)
    {
      echo "### ${name}"
      echo
      printf '%s\n' "$excerpt"
      echo
    } >>"$out"
  done < <(git diff --name-only | grep -E '(^|/)CHANGELOG\.md$' || true)

  node -e 'const fs=require("fs");const p=process.argv[1];const m=55000;let t=fs.readFileSync(p,"utf8");if(t.length>m){t=t.slice(0,m)+"\n\n_(body truncated for GitHub length limits)_\n";fs.writeFileSync(p,t);}' "$out" 2>/dev/null || true
}

build_force_with_lease_arg() {
  local remote_url branch remote_head=""
  remote_url=$1
  branch=$2
  remote_head=$(git ls-remote --heads "$remote_url" "$branch" | awk 'NR==1 { print $1 }' || true)
  if [[ -n "$remote_head" ]]; then
    printf '%s' "--force-with-lease=${branch}:${remote_head}"
  else
    printf '%s' "--force-with-lease"
  fi
}

run_changesets_release_pr_main() {
  local pnpm_bin app_dir primary pending title release_branch repo_slug u r pr_num auth_header push_url lease_arg push_output
  # body_file is intentionally not local: the EXIT trap runs after this function returns.
  pnpm_bin=${PNPM_BINARY:-pnpm}
  app_dir=${APP_DIR:-.}
  primary=${PRIMARY_BRANCH:?PRIMARY_BRANCH is required}

  cd "$app_dir"

  pending=$(count_pending_changesets)
  if [[ "$pending" -eq 0 ]]; then
    echo "runChangesetsReleasePr: no pending changeset files under .changeset/; skipping release PR."
    exit 0
  fi

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "runChangesetsReleasePr: GITHUB_TOKEN must be set for git push and gh." >&2
    exit 1
  fi

  export GH_TOKEN="$GITHUB_TOKEN"

  git fetch origin "$primary"
  git checkout "$primary"
  git reset --hard "origin/${primary}"

  "$pnpm_bin" exec changeset version

  if ! title=$(build_title); then
    echo "runChangesetsReleasePr: changeset version produced no package.json changes (e.g. empty or verification-only changesets); skipping release PR."
    exit 0
  fi
  if [[ -n "${BODY_FILE:-}" ]]; then
    body_file=$BODY_FILE
  else
    body_file=$(mktemp)
    trap 'rm -f "$body_file"' EXIT
  fi
  build_pr_body_file "$body_file"

  release_branch="release/${primary}"

  git checkout -B "$release_branch"
  git add -A
  # Commit subject must match PR title (single-line).
  git commit -m "$title"

  repo_slug=${GITHUB_REPO_SLUG:-}
  if [[ -z "$repo_slug" ]]; then
    u=${CIRCLE_PROJECT_USERNAME:-}
    r=${CIRCLE_PROJECT_REPONAME:-}
    if [[ -n "$u" && -n "$r" ]]; then
      repo_slug="${u}/${r}"
    fi
  fi
  if [[ -z "$repo_slug" ]]; then
    echo "runChangesetsReleasePr: set GITHUB_REPO_SLUG or CIRCLE_PROJECT_USERNAME and CIRCLE_PROJECT_REPONAME for push/PR." >&2
    exit 1
  fi

  push_url="https://github.com/${repo_slug}.git"

  # Refresh both default and release heads so lease checks use current remote state.
  git fetch origin "$release_branch" || true

  auth_header=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')
  lease_arg=$(build_force_with_lease_arg "$push_url" "$release_branch")
  if ! push_output=$(git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
    push -u "$push_url" "$release_branch" "$lease_arg" 2>&1); then
    printf '%s\n' "$push_output" >&2
    if [[ "$push_output" == *"stale info"* ]]; then
      # Retry once with a fresh lease in case branch state moved since earlier fetch.
      lease_arg=$(build_force_with_lease_arg "$push_url" "$release_branch")
      git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
        push -u "$push_url" "$release_branch" "$lease_arg"
    else
      exit 1
    fi
  else
    printf '%s\n' "$push_output"
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "runChangesetsReleasePr: gh CLI not found on PATH after install step." >&2
    exit 1
  fi

  pr_num=$(gh pr list --repo "$repo_slug" --head "$release_branch" --base "$primary" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)

  if [[ -n "$pr_num" ]]; then
    gh pr edit "$pr_num" --repo "$repo_slug" --title "$title" --body-file "$body_file"
    echo "runChangesetsReleasePr: updated PR #${pr_num}"
  else
    gh pr create --repo "$repo_slug" --base "$primary" --head "$release_branch" --title "$title" --body-file "$body_file"
    echo "runChangesetsReleasePr: created release PR"
  fi
}

if [[ "${CHANGESETS_RELEASE_PR_SOURCE_ONLY:-}" != "true" ]]; then
  run_changesets_release_pr_main "$@"
fi
