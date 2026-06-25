#! /usr/bin/env bash
# Push staging- or prod- promotion tag at merge commit when prefix is set (ADR 0031). No-op when empty.
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

read_manifest_release_id() {
  local manifest=$1
  if [[ ! -f "$manifest" ]]; then
    echo "pushPromotionTag: expected manifest at ${manifest} when promotion-tag-prefix is set." >&2
    echo "  Enable create-release-manifest on changesets-release-pr and list deployable-packages." >&2
    exit 1
  fi
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const t = fs.readFileSync(p, "utf8");
    const m = t.match(/^release:\s*["\x27]?([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)["\x27]?\s*$/m);
    if (!m) {
      process.stderr.write("pushPromotionTag: could not read release field from manifest\n");
      process.exit(1);
    }
    process.stdout.write(m[1]);
  ' "$manifest"
}

push_promotion_tag_main() {
  local prefix raw_prefix release_id tag target_ref target_sha remote_sha on_existing
  local repo_slug u r auth_header push_url manifest releases_dir app_dir

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
  if [[ -z "$raw_prefix" ]]; then
    echo "pushPromotionTag: promotion-tag-prefix must not be empty." >&2
    exit 1
  fi

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "pushPromotionTag: GITHUB_TOKEN must be set to push promotion tags." >&2
    exit 1
  fi

  releases_dir=${RELEASES_DIR:-.releases}
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

  manifest=""
  shopt -s nullglob
  local -a manifest_candidates=("${releases_dir}"/*.yml)
  shopt -u nullglob 2>/dev/null || true
  if [[ ${#manifest_candidates[@]} -eq 0 ]]; then
    manifest=""
  elif [[ ${#manifest_candidates[@]} -eq 1 ]]; then
    manifest=${manifest_candidates[0]}
  else
    echo "pushPromotionTag: expected one manifest under ${releases_dir}/, found ${#manifest_candidates[@]}." >&2
    exit 1
  fi

  if [[ -z "$manifest" ]]; then
    echo "pushPromotionTag: no manifest under ${releases_dir}/ on merge commit." >&2
    exit 1
  fi

  release_id=$(read_manifest_release_id "$manifest")
  tag="${raw_prefix}-${release_id}"

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
