#! /usr/bin/env bash
# Finalize a release cycle for production: promotedAt, release-notes rollup, commit, prod tag, GitHub Release.
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

run_promote_prod_release_main() {
  local app_dir releases_dir cycle_dir finalize_script notes_path primary auth_header push_url repo_slug u r
  local target_ref target_sha tag remote_sha on_existing

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
  target_sha=$(git rev-parse "${target_ref}^{commit}")
  export TARGET_SHA="$target_sha"

  if ! read_cycle_from_commit; then
    echo "runPromoteProdRelease: could not determine cycle id on ${target_ref}." >&2
    exit 1
  fi

  cycle_dir="${releases_dir}/${CYCLE_ID}"
  if [[ ! -d "$cycle_dir" ]]; then
    echo "runPromoteProdRelease: missing cycle directory ${cycle_dir}." >&2
    exit 1
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

  git add "${cycle_dir}/cycle.yml" "$notes_path"
  if git diff --cached --quiet; then
    echo "runPromoteProdRelease: cycle already finalized on ${target_ref}; continuing."
  else
    git commit --no-verify -m "chore(release): finalize ${CYCLE_ID} for production"
    target_sha=$(git rev-parse HEAD)
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
    if [[ "$remote_sha" == "$target_sha" ]]; then
      if [[ "$on_existing" == "skip" ]]; then
        echo "runPromoteProdRelease: tag ${tag} already exists at ${target_sha}; skipping tag push."
      else
        echo "runPromoteProdRelease: tag ${tag} already exists at target (on-existing-tag=fail)." >&2
        exit 1
      fi
    else
      echo "runPromoteProdRelease: tag ${tag} exists on origin at ${remote_sha}, not ${target_sha}." >&2
      exit 1
    fi
  else
    git -c tag.gpgSign=false tag -fa "$tag" -m "promotion: ${tag}" "$target_sha"
    git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
      push "$push_url" "refs/tags/${tag}"
    echo "runPromoteProdRelease: pushed ${tag} at ${target_sha}."
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

  gh release create "$tag" --repo "$repo_slug" --target "$target_sha" \
    --title "$CYCLE_ID" --notes-file "$notes_path"
  echo "runPromoteProdRelease: created GitHub Release ${tag}."
}

if [[ "${PROMOTE_PROD_RELEASE_SOURCE_ONLY:-}" != "true" ]]; then
  run_promote_prod_release_main "$@"
fi
