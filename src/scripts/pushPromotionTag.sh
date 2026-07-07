#! /usr/bin/env bash
# Push staging-<cycle-id>-rc<n> or prod-<cycle-id> promotion tag at merge commit (ADR 0031, ADR 0042).
set -euo pipefail

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

_resolve_cycle_script() {
  if [[ -n "${RESOLVE_RELEASE_CYCLE_SCRIPT:-}" && -f "${RESOLVE_RELEASE_CYCLE_SCRIPT}" ]]; then
    printf '%s\n' "$RESOLVE_RELEASE_CYCLE_SCRIPT"
    return 0
  fi
  local sibling
  # shellcheck disable=SC3028
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/resolveReleaseCycleOnCommit.mjs"
  if [[ -f "$sibling" ]]; then
    printf '%s\n' "$sibling"
    return 0
  fi
  echo "pushPromotionTag: set RESOLVE_RELEASE_CYCLE_SCRIPT or keep resolveReleaseCycleOnCommit.mjs next to this script." >&2
  return 1
}

read_cycle_from_commit() {
  local resolver cycle_id rc_index line key value
  if ! resolver=$(_resolve_cycle_script); then
    return 1
  fi
  cycle_id=""
  rc_index=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      CYCLE_ID) cycle_id=$value ;;
      RC_INDEX) rc_index=$value ;;
    esac
  done < <(node "$resolver")
  if [[ -z "$cycle_id" || -z "$rc_index" ]]; then
    echo "pushPromotionTag: could not resolve cycle id and RC index on commit." >&2
    return 1
  fi
  RELEASE_ID=$cycle_id
  RC_INDEX=$rc_index
}

push_promotion_tag_main() {
  local prefix raw_prefix release_id rc_index tag target_ref target_sha remote_sha on_existing
  local repo_slug u r auth_header push_url app_dir

  prefix=${PROMOTION_TAG_PREFIX:-}
  if [[ -z "$prefix" ]]; then
    echo "pushPromotionTag: promotion-tag-prefix empty; skipping."
    exit 0
  fi

  raw_prefix=$prefix
  if [[ "$raw_prefix" == *- ]]; then
    echo "pushPromotionTag: promotion-tag-prefix must not include a trailing hyphen (got \"${prefix}\")." >&2
    exit 1
  fi

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "pushPromotionTag: GITHUB_TOKEN must be set to push promotion tags." >&2
    exit 1
  fi

  app_dir=${APP_DIR:-.}
  cd "$app_dir"

  target_ref=${TARGET_REF:-}
  if [[ -z "$target_ref" ]] && [[ -n "${CIRCLE_SHA1:-}" ]]; then
    if git rev-parse --verify "${CIRCLE_SHA1}^{commit}" >/dev/null 2>&1; then
      target_ref=${CIRCLE_SHA1}
    fi
  fi
  if [[ -z "$target_ref" ]]; then
    target_ref=HEAD
  fi
  target_sha=$(resolve_target_sha "$target_ref")

  if ! read_cycle_from_commit; then
    echo "pushPromotionTag: expected .releases/<cycle-id>/rc<n>/ on merge commit." >&2
    echo "  Enable create-release-manifest on changesets-release-pr and list deployable-packages." >&2
    exit 1
  fi
  release_id=$RELEASE_ID
  rc_index=$RC_INDEX

  if [[ "$raw_prefix" == "prod" ]]; then
    tag="${raw_prefix}-${release_id}"
  else
    tag="${raw_prefix}-${release_id}-rc${rc_index}"
  fi

  on_existing=${ON_EXISTING_TAG:-skip}
  remote_sha=$(remote_peeled_commit_for_tag "$tag")
  if [[ -n "$remote_sha" ]]; then
    if [[ "$remote_sha" == "$target_sha" ]]; then
      if [[ "$on_existing" == "skip" ]]; then
        echo "pushPromotionTag: tag ${tag} already exists at ${target_sha}; skipping."
        exit 0
      fi
      echo "pushPromotionTag: tag ${tag} already exists at target (on-existing-tag=fail)." >&2
      exit 1
    fi
    echo "pushPromotionTag: tag ${tag} exists on origin at ${remote_sha}, not ${target_sha}." >&2
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
    echo "pushPromotionTag: set GITHUB_REPO_SLUG or CIRCLE_PROJECT_* for git push." >&2
    exit 1
  fi

  push_url="https://github.com/${repo_slug}.git"
  auth_header=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')

  git -c tag.gpgSign=false tag -a "$tag" -m "promotion: ${tag}" "$target_sha"
  git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
    push "$push_url" "refs/tags/${tag}"
  echo "pushPromotionTag: pushed ${tag} at ${target_sha}."
}

if [[ "${PUSH_PROMOTION_TAG_SOURCE_ONLY:-}" != "true" ]]; then
  push_promotion_tag_main "$@"
fi
