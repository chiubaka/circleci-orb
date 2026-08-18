#! /usr/bin/env bash
# Finalize a release cycle for production: optional pre-exit + stable version (ADR 0043),
# promotedAt, release-notes rollup, commit, prod tag, GitHub Release.
set -euo pipefail

_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd
}

_resolve_finalize_script() {
  if [[ -n "${FINALIZE_RELEASE_CYCLE_SCRIPT:-}" && -f "${FINALIZE_RELEASE_CYCLE_SCRIPT}" ]]; then
    printf '%s\n' "$FINALIZE_RELEASE_CYCLE_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(_script_dir)/finalizeReleaseCycle.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runPromoteProdRelease: set FINALIZE_RELEASE_CYCLE_SCRIPT or keep finalizeReleaseCycle.mjs next to this script." >&2
  return 1
}

_resolve_refresh_pins_script() {
  if [[ -n "${REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT:-}" && -f "${REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT}" ]]; then
    printf '%s\n' "$REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT"
    return 0
  fi
  local sibling
  sibling="$(_script_dir)/refreshHighestRcManifestPins.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "runPromoteProdRelease: set REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT or keep refreshHighestRcManifestPins.mjs next to this script." >&2
  return 1
}

_read_pre_mode() {
  if [[ ! -f .changeset/pre.json ]]; then
    printf ''
    return 0
  fi
  node -e 'const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(".changeset/pre.json","utf8"));process.stdout.write(String(j.mode||""));}catch{process.stdout.write("");}'
}

list_changed_changelog_paths() {
  {
    git diff --name-only
    git ls-files --others --exclude-standard
  } | { grep -E '(^|/)CHANGELOG\.md$' || :; } | LC_ALL=C sort -u
}

_resolve_rewriter_script() {
  if [[ -n "${REWRITE_CHANGELOG_CATEGORIES_SCRIPT:-}" && -f "${REWRITE_CHANGELOG_CATEGORIES_SCRIPT}" ]]; then
    printf '%s\n' "$REWRITE_CHANGELOG_CATEGORIES_SCRIPT"
    return 0
  fi
  local sibling
  sibling="$(_script_dir)/rewriteChangelogCategories.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  return 1
}

rewrite_changelogs_for_category_grouping() {
  local grouping_lower rewriter
  grouping_lower=$(printf '%s' "${RELEASE_NOTES_GROUPING:-category}" | tr '[:upper:]' '[:lower:]')
  if [[ "$grouping_lower" != "category" ]]; then
    return 0
  fi
  if ! rewriter=$(_resolve_rewriter_script); then
    echo "runPromoteProdRelease: category grouping requires REWRITE_CHANGELOG_CATEGORIES_SCRIPT." >&2
    return 1
  fi
  local -a cpaths=()
  mapfile -t cpaths < <(list_changed_changelog_paths | grep -v '^$' || true)
  if [[ ${#cpaths[@]} -eq 0 ]]; then
    return 0
  fi
  node "$rewriter" "${cpaths[@]}"
}

# ADR 0043: exit Changesets prerelease and cut stable semver before production pins.
# Sets DID_STABLE_CUT=true when a pre-exit version cut runs.
exit_prerelease_and_cut_stable() {
  local pnpm_bin pre_mode refresh_script
  pnpm_bin=${PNPM_BINARY:-pnpm}
  DID_STABLE_CUT=false
  pre_mode=$(_read_pre_mode)

  if [[ -z "$pre_mode" ]]; then
    echo "runPromoteProdRelease: not in Changesets prerelease mode; skipping pre-exit version cut (hotfix or legacy cycle)."
    return 0
  fi

  if [[ -z "${DEPLOYABLE_PACKAGES:-}" ]]; then
    echo "runPromoteProdRelease: DEPLOYABLE_PACKAGES is required to refresh stable manifest pins after pre-exit." >&2
    return 1
  fi
  if ! refresh_script=$(_resolve_refresh_pins_script); then
    return 1
  fi

  if [[ "$pre_mode" == "pre" ]]; then
    echo "runPromoteProdRelease: exiting Changesets prerelease mode for production stable cut."
    "$pnpm_bin" exec changeset pre exit
  elif [[ "$pre_mode" == "exit" ]]; then
    echo "runPromoteProdRelease: Changesets pre.json already in exit mode; running version to stable."
  else
    echo "runPromoteProdRelease: unexpected .changeset/pre.json mode '${pre_mode}'." >&2
    return 1
  fi

  "$pnpm_bin" exec changeset version
  rewrite_changelogs_for_category_grouping

  RELEASE_ID="${CYCLE_ID}" node "$refresh_script"
  DID_STABLE_CUT=true

  if [[ -n "${STABLE_PUBLISH_SCRIPT:-}" ]]; then
    echo "runPromoteProdRelease: running stable publish script: ${STABLE_PUBLISH_SCRIPT}"
    "$pnpm_bin" run "$STABLE_PUBLISH_SCRIPT"
  else
    echo "runPromoteProdRelease: STABLE_PUBLISH_SCRIPT unset; ensure stable artifact tags are published for refreshed manifest pins."
  fi
}

read_cycle_from_commit() {
  local resolver cycle_id line key value
  if [[ -n "${RELEASE_ID:-}" ]]; then
    CYCLE_ID=$RELEASE_ID
    return 0
  fi
  resolver=${RESOLVE_RELEASE_CYCLE_SCRIPT:-}
  if [[ -z "$resolver" || ! -f "$resolver" ]]; then
    resolver="$(_script_dir)/resolveReleaseCycleOnCommit.mjs"
  fi
  if [[ ! -f "$resolver" ]]; then
    echo "runPromoteProdRelease: could not resolve release cycle on commit." >&2
    return 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      CYCLE_ID) cycle_id=$value ;;
    esac
  done < <(RELEASES_DIR="${RELEASES_DIR:-.releases}" node "$resolver")
  if [[ -z "$cycle_id" ]]; then
    return 1
  fi
  CYCLE_ID=$cycle_id
}

_resolve_tag_sha() {
  local tag_target validated_sha finalize_sha did_stable
  tag_target=$(printf '%s' "${TAG_TARGET:-finalize}" | tr '[:upper:]' '[:lower:]')
  validated_sha=$1
  finalize_sha=$2
  did_stable=${DID_STABLE_CUT:-false}
  case "$tag_target" in
    finalize) printf '%s\n' "$finalize_sha" ;;
    validated)
      if [[ "$did_stable" == "true" ]]; then
        echo "runPromoteProdRelease: TAG_TARGET=validated is incompatible after ADR 0043 stable cut (pins live on the finalize commit). Use finalize." >&2
        return 1
      fi
      printf '%s\n' "$validated_sha"
      ;;
    *)
      echo "runPromoteProdRelease: TAG_TARGET must be finalize or validated (got ${TAG_TARGET})." >&2
      return 1
      ;;
  esac
}

# Finalize commit and annotated prod tags need identity. The promote-prod-release
# job configures this via configure-git-user; fail early when callers skip that step.
_require_git_identity() {
  local name email
  name=$(git config user.name 2>/dev/null || true)
  email=$(git config user.email 2>/dev/null || true)
  if [[ -z "$name" || -z "$email" ]]; then
    echo "runPromoteProdRelease: git user.name and user.email must be set before the finalize commit or annotated prod tag (enable the job configure-git-user step, or set git-user-name / git-user-email)." >&2
    return 1
  fi
}

run_promote_prod_release_main() {
  local app_dir releases_dir cycle_dir finalize_script notes_path primary auth_header push_url repo_slug u r
  local target_ref validated_sha finalize_sha tag_sha tag remote_sha on_existing

  app_dir=${APP_DIR:-.}
  releases_dir=${RELEASES_DIR:-.releases}
  primary=${PRIMARY_BRANCH:?PRIMARY_BRANCH is required}
  cd "$app_dir"

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "runPromoteProdRelease: GITHUB_TOKEN must be set." >&2
    exit 1
  fi
  export GH_TOKEN="$GITHUB_TOKEN"

  target_ref=${TARGET_REF:-}
  if [[ -z "$target_ref" ]] && [[ -n "${CIRCLE_SHA1:-}" ]]; then
    if git rev-parse --verify "${CIRCLE_SHA1}^{commit}" >/dev/null 2>&1; then
      target_ref=${CIRCLE_SHA1}
    fi
  fi
  if [[ -z "$target_ref" ]]; then
    target_ref=HEAD
  fi
  validated_sha=$(git rev-parse "${target_ref}^{commit}")
  finalize_sha=$validated_sha
  export TARGET_SHA="$validated_sha"

  git checkout --detach "$validated_sha" >/dev/null 2>&1 || git checkout "$validated_sha"

  if ! read_cycle_from_commit; then
    echo "runPromoteProdRelease: could not determine cycle id on ${target_ref}." >&2
    exit 1
  fi

  cycle_dir="${releases_dir}/${CYCLE_ID}"
  if [[ ! -d "$cycle_dir" ]]; then
    echo "runPromoteProdRelease: missing cycle directory ${cycle_dir}." >&2
    exit 1
  fi

  # Call as a standalone command so set -e applies inside the function body.
  # (Bash disables errexit for commands in `if` conditions.)
  exit_prerelease_and_cut_stable

  if [[ "${DID_STABLE_CUT:-false}" == "true" ]]; then
    local -a stable_changelog_paths=()
    mapfile -t stable_changelog_paths < <(list_changed_changelog_paths | grep -v '^$' || true)
    STABLE_RELEASE_NOTES_CHANGELOG_PATHS=$(
      IFS=,
      printf '%s' "${stable_changelog_paths[*]}"
    )
    export STABLE_RELEASE_NOTES_CHANGELOG_PATHS
  else
    unset STABLE_RELEASE_NOTES_CHANGELOG_PATHS
  fi

  if ! finalize_script=$(_resolve_finalize_script); then
    exit 1
  fi
  _finalize_tmp=$(mktemp)
  if ! node "$finalize_script" "$cycle_dir" >"$_finalize_tmp"; then
    rm -f "$_finalize_tmp"
    exit 1
  fi
  mapfile -t _finalize_out <"$_finalize_tmp"
  rm -f "$_finalize_tmp"
  notes_path="${cycle_dir}/release-notes.md"

  git add -A
  if git diff --cached --quiet; then
    echo "runPromoteProdRelease: cycle already finalized on ${target_ref}; continuing."
  else
    if ! _require_git_identity; then
      exit 1
    fi
    git commit --no-verify -m "chore(release): finalize ${CYCLE_ID} for production"
    finalize_sha=$(git rev-parse HEAD)
  fi

  if ! tag_sha=$(_resolve_tag_sha "$validated_sha" "$finalize_sha"); then
    exit 1
  fi

  repo_slug=${GITHUB_REPO_SLUG:-}
  if [[ -z "$repo_slug" ]]; then
    u=${CIRCLE_PROJECT_USERNAME:-}
    r=${CIRCLE_PROJECT_REPONAME:-}
    if [[ -n "$u" && -n "$r" ]]; then
      repo_slug="${u}/${r}"
    fi
  fi
  if [[ -z "$repo_slug" ]]; then
    echo "runPromoteProdRelease: set GITHUB_REPO_SLUG or CIRCLE_PROJECT_* for git push." >&2
    exit 1
  fi

  push_url="https://github.com/${repo_slug}.git"
  auth_header=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')
  git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
    push "$push_url" "HEAD:${primary}"

  tag="prod-${CYCLE_ID}"
  on_existing=${ON_EXISTING_TAG:-skip}
  remote_sha=$(git ls-remote origin "refs/tags/${tag}^{}" | awk '{print $1}' | head -1 || true)
  if [[ -z "$remote_sha" ]]; then
    remote_sha=$(git ls-remote origin "refs/tags/${tag}" | awk '{print $1}' | head -1 || true)
  fi
  if [[ -n "$remote_sha" ]]; then
    if [[ "$remote_sha" == "$tag_sha" ]]; then
      if [[ "$on_existing" == "skip" ]]; then
        echo "runPromoteProdRelease: tag ${tag} already exists at ${tag_sha}; skipping tag push."
      else
        echo "runPromoteProdRelease: tag ${tag} already exists at target (on-existing-tag=fail)." >&2
        exit 1
      fi
    else
      echo "runPromoteProdRelease: tag ${tag} exists on origin at ${remote_sha}, not ${tag_sha}." >&2
      exit 1
    fi
  else
    if ! _require_git_identity; then
      exit 1
    fi
    git -c tag.gpgSign=false tag -fa "$tag" -m "promotion: ${tag}" "$tag_sha"
    git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
      push "$push_url" "refs/tags/${tag}"
    echo "runPromoteProdRelease: pushed ${tag} at ${tag_sha}."
  fi

  create_raw=${CREATE_GITHUB_RELEASE:-true}
  create_lower=$(printf '%s' "$create_raw" | tr '[:upper:]' '[:lower:]')
  if [[ "$create_lower" != "true" ]] && [[ "$create_lower" != "1" ]]; then
    echo "runPromoteProdRelease: CREATE_GITHUB_RELEASE=false; skipping GitHub Release."
    exit 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "runPromoteProdRelease: gh CLI not found on PATH; run install-github-cli first." >&2
    exit 1
  fi

  if gh release view "$tag" --repo "$repo_slug" >/dev/null 2>&1; then
    echo "runPromoteProdRelease: GitHub Release ${tag} already exists; skipping."
    exit 0
  fi

  gh release create "$tag" --repo "$repo_slug" --target "$tag_sha" \
    --title "$CYCLE_ID" --notes-file "$notes_path"
  echo "runPromoteProdRelease: created GitHub Release ${tag}."
}

if [[ "${PROMOTE_PROD_RELEASE_SOURCE_ONLY:-}" != "true" ]]; then
  run_promote_prod_release_main "$@"
fi
