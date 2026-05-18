#! /usr/bin/env bash
# Parse staging-YYYY.MM.DD.N or prod-YYYY.MM.DD.N (ADR 0031).
# Sets PROMOTION_ENV and RELEASE_ID. Reads CIRCLE_TAG or TAG.
set -euo pipefail

parse_promotion_tag_main() {
  local tag raw env rest
  raw=${CIRCLE_TAG:-${TAG:-}}
  if [[ -z "$raw" ]]; then
    echo "parsePromotionTag: CIRCLE_TAG or TAG must be set." >&2
    exit 1
  fi
  tag=${raw#v}

  if [[ "$tag" =~ ^staging-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)$ ]]; then
    env=staging
    rest="${BASH_REMATCH[1]}"
  elif [[ "$tag" =~ ^prod-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)$ ]]; then
    env=prod
    rest="${BASH_REMATCH[1]}"
  else
    echo "parsePromotionTag: tag must match staging-YYYY.MM.DD.N or prod-YYYY.MM.DD.N (got: ${tag})." >&2
    echo "  See ADR 0031 for promotion tag conventions." >&2
    exit 1
  fi

  export PROMOTION_ENV="$env"
  export RELEASE_ID="$rest"
  printf 'PROMOTION_ENV=%s\n' "$PROMOTION_ENV"
  printf 'RELEASE_ID=%s\n' "$RELEASE_ID"
}

if [[ "${PARSE_PROMOTION_TAG_SOURCE_ONLY:-}" != "true" ]]; then
  parse_promotion_tag_main "$@"
fi
