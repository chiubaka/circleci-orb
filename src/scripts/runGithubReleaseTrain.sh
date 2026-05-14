#! /usr/bin/env bash
# GitHub Release train (ADR 0037): UTC calendar train id YYYY.MM.DD.N, git tag prefix + id, title = logical id.
# Release notes for default merge-commit mode come from HEAD~1..HEAD CHANGELOG.md diffs, formatted by
# formatChangesetsBatchReleaseNotes.mjs (same shape as runChangesetsReleasePr.sh build_pr_body_file).
# Optional test-only: UTC_DATE_OVERRIDE=YYYY.MM.DD fixes the calendar portion; GITHUB_RELEASE_TRAIN_KEEP_NOTES_FILE=true skips deleting the temp notes file after exit (Bats).
set -euo pipefail

pkg_at_version() {
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const j = JSON.parse(fs.readFileSync(p, "utf8"));
    if (j.name && j.version) process.stdout.write(j.name + "@" + j.version);
  ' "$1" 2>/dev/null || true
}

extract_changelog_top() {
  local file=$1
  [[ -f "$file" ]] || return 0
  awk '
    /^## [0-9]/ { if (++s == 1) next; if (s > 1) exit }
    s == 1 { print }
  ' "$file"
}

regex_escape_basic() {
  printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|]/\\&/g'
}

assert_origin_is_github_com() {
  local url
  url=$(git config --get remote.origin.url 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    url=$(git remote get-url origin 2>/dev/null || true)
  fi
  if [[ -z "$url" ]]; then
    echo "runGithubReleaseTrain: no git remote named origin; cannot verify GitHub host." >&2
    exit 1
  fi
  if [[ "$url" == git@github.com:* ]] \
    || [[ "$url" == ssh://git@github.com/* ]] \
    || [[ "$url" == https://github.com/* ]] \
    || [[ "$url" == https://*@github.com/* ]] \
    || [[ "$url" == http://github.com/* ]] \
    || [[ "$url" == http://*@github.com/* ]]; then
    return 0
  fi
  echo "runGithubReleaseTrain: origin must point at github.com for gh releases." >&2
  echo "  url: ${url}" >&2
  echo "  Fix origin, disable create-github-release, or use a github.com mirror for releases." >&2
  exit 1
}

utc_calendar_date_str() {
  if [[ -n "${UTC_DATE_OVERRIDE:-}" ]]; then
    printf '%s' "$UTC_DATE_OVERRIDE"
    return
  fi
  date -u +%Y.%m.%d
}

# stdin: git ls-remote --tags style lines; args: train_tag_prefix date_str
max_n_from_ls_remote_for_date() {
  local prefix=$1 date_str=$2 escaped_prefix escaped_date pattern line ref tag_suffix n max_n=-1
  escaped_prefix=$(regex_escape_basic "$prefix")
  escaped_date=$(regex_escape_basic "$date_str")
  pattern="^${escaped_prefix}${escaped_date}\\.[0-9]+$"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    ref=$(awk '{print $2}' <<<"$line")
    [[ "$ref" == refs/tags/* ]] || continue
    ref=${ref#refs/tags/}
    [[ "$ref" == *'^'* ]] && ref=${ref%^*}
    [[ "$ref" =~ $pattern ]] || continue
    tag_suffix=${ref#"$prefix"}
    n=${tag_suffix##*.}
    if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -gt "$max_n" ]]; then
      max_n=$n
    fi
  done
  if [[ "$max_n" -lt 0 ]]; then
    printf '%s' "0"
  else
    printf '%s' "$max_n"
  fi
}

compute_next_train_id_for_date() {
  local prefix=$1 date_str=$2 ls_out max_n next_n
  ls_out=$(git ls-remote --tags origin 2>/dev/null || true)
  max_n=$(printf '%s\n' "$ls_out" | max_n_from_ls_remote_for_date "$prefix" "$date_str")
  next_n=$((max_n + 1))
  printf '%s' "${date_str}.${next_n}"
}

compute_next_train_id() {
  compute_next_train_id_for_date "${TRAIN_TAG_PREFIX:-release/}" "$(utc_calendar_date_str)"
}

remote_train_tag_for_date_points_at_target() {
  local prefix=$1 date_str=$2 target_sha=$3
  local escaped_prefix escaped_date pattern line ref name peel
  escaped_prefix=$(regex_escape_basic "$prefix")
  escaped_date=$(regex_escape_basic "$date_str")
  pattern="^${escaped_prefix}${escaped_date}\\.[0-9]+$"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    ref=$(awk '{print $2}' <<<"$line")
    [[ "$ref" == refs/tags/* ]] || continue
    name=${ref#refs/tags/}
    name=${name%^*}
    [[ "$name" =~ $pattern ]] || continue
    peel=$(remote_peeled_commit_for_tag "$name")
    if [[ -n "$peel" && "$peel" == "$target_sha" ]]; then
      return 0
    fi
  done < <(git ls-remote --tags origin 2>/dev/null || true)
  return 1
}

list_merge_changelog_paths() {
  git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '(^|/)CHANGELOG\.md$' || true
}

truncate_notes_file() {
  local out=$1 max=${2:-120000}
  node -e 'const fs=require("fs");const p=process.argv[1];const m=+process.argv[2];let t=fs.readFileSync(p,"utf8");if(t.length>m){t=t.slice(0,m)+"\n\n_(body truncated for GitHub length limits)_\n";fs.writeFileSync(p,t);}' "$out" "$max" 2>/dev/null || true
}

_resolve_formatter_script() {
  if [[ -n "${FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT:-}" && -f "${FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT}" ]]; then
    printf '%s\n' "$FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/formatChangesetsBatchReleaseNotes.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runGithubReleaseTrain: set FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT or keep formatChangesetsBatchReleaseNotes.mjs next to this script." >&2
  return 1
}

build_release_notes_merge() {
  local out=$1 fmt
  if ! fmt=$(_resolve_formatter_script); then
    return 1
  fi
  local -a cpaths=()
  mapfile -t cpaths < <(list_merge_changelog_paths | grep -v '^$' || true)
  if [[ ${#cpaths[@]} -eq 0 ]]; then
    echo "runGithubReleaseTrain: internal error: no changelog paths after merge diff check." >&2
    return 1
  fi
  node "$fmt" "$out" "${cpaths[@]}"
  truncate_notes_file "$out"
}

prepend_notes_extra() {
  local body=$1 extra=$2 merged
  merged=$(mktemp)
  {
    if [[ -f "$extra" ]]; then
      cat "$extra"
      echo
    fi
    cat "$body"
  } >"$merged"
  mv "$merged" "$body"
  truncate_notes_file "$body"
}

remote_peeled_commit_for_tag() {
  local tag=$1 line
  line=$(git ls-remote origin "refs/tags/${tag}^{}" | head -1 || true)
  if [[ -n "$line" ]]; then
    awk '{print $1}' <<<"$line"
    return 0
  fi
  line=$(git ls-remote origin "refs/tags/${tag}" | head -1 || true)
  if [[ -n "$line" ]]; then
    awk '{print $1}' <<<"$line"
    return 0
  fi
  printf ''
}

resolve_target_sha() {
  local ref=$1
  git rev-parse "${ref}^{commit}" 2>/dev/null || git rev-parse "$ref"
}

apply_title_template() {
  local template=$1 logical=$2
  printf '%s' "${template//\{\{logical_train_id\}\}/$logical}"
}

run_github_release_train_main() {
  local app_dir prefix logical_id git_tag target_ref target_sha train_date_str notes_src body_file gh_err gh_extra=() remote_sha
  local on_existing draft_lower pre_lower attempt notes_extra fail_notes

  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  assert_origin_is_github_com

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "runGithubReleaseTrain: GITHUB_TOKEN must be set for gh release create." >&2
    exit 1
  fi
  export GH_TOKEN="$GITHUB_TOKEN"

  prefix=${TRAIN_TAG_PREFIX:-release/}

  target_ref=${TARGET_REF:-}
  # CircleCI sets CIRCLE_SHA1 for the job checkout. Bats fixtures use a separate git clone; inheriting
  # CIRCLE_SHA1 would point at a commit that does not exist in the fixture repo and break tag/HEAD logic.
  if [[ -z "$target_ref" ]] && [[ -n "${CIRCLE_SHA1:-}" ]]; then
    if git rev-parse --verify "${CIRCLE_SHA1}^{commit}" >/dev/null 2>&1; then
      target_ref=${CIRCLE_SHA1}
    fi
  fi
  if [[ -z "$target_ref" ]]; then
    target_ref=HEAD
  fi
  target_sha=$(resolve_target_sha "$target_ref")

  train_date_str=$(utc_calendar_date_str)
  on_existing=${ON_EXISTING_TAG:-skip}
  if remote_train_tag_for_date_points_at_target "$prefix" "$train_date_str" "$target_sha"; then
    if [[ "$on_existing" == "skip" ]]; then
      echo "runGithubReleaseTrain: a ${prefix}${train_date_str}.* tag already exists at ${target_sha}; skipping (on-existing-tag=skip)."
      exit 0
    fi
    echo "runGithubReleaseTrain: a ${prefix}${train_date_str}.* tag already exists at the target commit (on-existing-tag=fail)." >&2
    exit 1
  fi

  logical_id=$(compute_next_train_id_for_date "$prefix" "$train_date_str")
  git_tag="${prefix}${logical_id}"

  notes_src=${RELEASE_NOTES_SOURCE:-merge-commit}
  body_file=$(mktemp)
  gh_err=$(mktemp)
  _cleanup_github_release_train_temps() {
    rm -f "$gh_err"
    if [[ "${GITHUB_RELEASE_TRAIN_KEEP_NOTES_FILE:-}" != "true" ]]; then
      rm -f "$body_file"
    fi
  }
  trap '_cleanup_github_release_train_temps' EXIT

  notes_extra=${NOTES_EXTRA_FILE:-}
  fail_notes="runGithubReleaseTrain: merge-commit mode requires at least one CHANGELOG.md path in git diff HEAD~1..HEAD (squash-merge the release PR so the merge commit parents include the prior tree)."

  if [[ "$notes_src" == "body-file" ]]; then
    if [[ -z "$notes_extra" || ! -f "$notes_extra" ]]; then
      echo "runGithubReleaseTrain: release-notes-source=body-file requires notes-extra-file pointing at an existing file." >&2
      exit 1
    fi
    cp "$notes_extra" "$body_file"
    truncate_notes_file "$body_file"
  else
    if ! git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
      echo "runGithubReleaseTrain: need at least two commits for HEAD~1..HEAD changelog diff." >&2
      exit 1
    fi
    mapfile -t _cl_paths < <(list_merge_changelog_paths)
    if [[ ${#_cl_paths[@]} -eq 0 ]]; then
      echo "runGithubReleaseTrain: no CHANGELOG.md paths in git diff HEAD~1..HEAD." >&2
      echo "  ${fail_notes}" >&2
      exit 1
    fi
    build_release_notes_merge "$body_file"
    if [[ -n "$notes_extra" && -f "$notes_extra" ]]; then
      prepend_notes_extra "$body_file" "$notes_extra"
    fi
  fi

  draft_lower=$(printf '%s' "${DRAFT:-false}" | tr '[:upper:]' '[:lower:]')
  pre_lower=$(printf '%s' "${PRERELEASE:-false}" | tr '[:upper:]' '[:lower:]')
  [[ "$draft_lower" == "true" ]] || [[ "$draft_lower" == "1" ]] && gh_extra+=(--draft)
  [[ "$pre_lower" == "true" ]] || [[ "$pre_lower" == "1" ]] && gh_extra+=(--prerelease)

  title_template=${TITLE_TEMPLATE:-'{{logical_train_id}}'}
  title=$(apply_title_template "$title_template" "$logical_id")

  remote_sha=$(remote_peeled_commit_for_tag "$git_tag")
  if [[ -n "$remote_sha" ]]; then
    if [[ "$remote_sha" == "$target_sha" ]]; then
      if [[ "$on_existing" == "skip" ]]; then
        echo "runGithubReleaseTrain: tag ${git_tag} already exists at target ${target_sha}; skipping (on-existing-tag=skip)."
        exit 0
      fi
      echo "runGithubReleaseTrain: tag ${git_tag} already exists at target but on-existing-tag=fail." >&2
      exit 1
    fi
    echo "runGithubReleaseTrain: tag ${git_tag} exists on origin pointing at ${remote_sha}, not ${target_sha}." >&2
    exit 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "runGithubReleaseTrain: gh CLI not found on PATH; run install-github-cli first." >&2
    exit 1
  fi

  for attempt in 1 2; do
    if gh release create "$git_tag" --target "$target_sha" --title "$title" --notes-file "$body_file" "${gh_extra[@]}" &>"$gh_err"; then
      echo "runGithubReleaseTrain: created GitHub release ${git_tag} (title: ${title})."
      exit 0
    fi
    cat "$gh_err" >&2 || true
    if [[ "$attempt" -eq 1 ]] && grep -qiE 'already exists|HTTP 422|Validation Failed|tag_name|name already' "$gh_err" 2>/dev/null; then
      echo "runGithubReleaseTrain: treating failure as possible tag/release race; recomputing train id (one retry)." >&2
      logical_id=$(compute_next_train_id_for_date "$prefix" "$train_date_str")
      git_tag="${prefix}${logical_id}"
      title=$(apply_title_template "$title_template" "$logical_id")
      remote_sha=$(remote_peeled_commit_for_tag "$git_tag")
      if [[ -n "$remote_sha" && "$remote_sha" == "$target_sha" && "$on_existing" == "skip" ]]; then
        echo "runGithubReleaseTrain: after retry, tag ${git_tag} already covers target; skipping."
        exit 0
      fi
      : >"$gh_err"
      continue
    fi
    exit 1
  done
}

if [[ "${GITHUB_RELEASE_TRAIN_SOURCE_ONLY:-}" != "true" ]]; then
  run_github_release_train_main "$@"
fi
