#! /usr/bin/env bash
# Parse staging-<cycle-id>-rc<n> or prod-<cycle-id> promotion tags (ADR 0031, ADR 0042).
# Sets PROMOTION_ENV, RELEASE_ID, and RC_INDEX (staging only).
set -euo pipefail

parse_promotion_tag_main() {
  local tag raw env rest rc_index=""
  raw=${CIRCLE_TAG:-${TAG:-}}
  if [[ -z "$raw" ]]; then
    echo "parsePromotionTag: CIRCLE_TAG or TAG must be set." >&2
    exit 1
  fi
  tag=${raw#v}

  if [[ "$tag" =~ ^staging-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)-rc([0-9]+)$ ]]; then
    env=staging
    rest="${BASH_REMATCH[1]}"
    rc_index="${BASH_REMATCH[2]}"
  elif [[ "$tag" =~ ^prod-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)$ ]]; then
    env=prod
    rest="${BASH_REMATCH[1]}"
  else
    echo "parsePromotionTag: tag must match staging-<cycle-id>-rc<n> or prod-<cycle-id> (got: ${tag})." >&2
    echo "  See ADR 0031 and ADR 0042 for promotion tag conventions." >&2
    exit 1
  fi

  export PROMOTION_ENV="$env"
  export RELEASE_ID="$rest"
  export RC_INDEX="$rc_index"
  printf 'PROMOTION_ENV=%s\n' "$PROMOTION_ENV"
  printf 'RELEASE_ID=%s\n' "$RELEASE_ID"
  if [[ -n "$rc_index" ]]; then
    printf 'RC_INDEX=%s\n' "$RC_INDEX"
  fi
}

if [[ "${PARSE_PROMOTION_TAG_SOURCE_ONLY:-}" != "true" ]]; then
  parse_promotion_tag_main "$@"
fi
