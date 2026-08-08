#!/usr/bin/env bash
# Emit JSON continuation parameters for Changesets publish / promote-prod gating:
#   {"run-changesets-publish": true|false, "offer-promote-prod": true|false}
# Default output path: /tmp/pipeline-parameters.json
#
# Mirrors merge-base / same-revision behavior from circleci/path-filtering create-parameters.sh.
# Path signal is true when:
#   - any CHANGELOG.md path changed in the diff, or
#   - any package.json had its top-level "version" field value change (including new files).
#
# run-changesets-publish is true only when the path signal is true AND HEAD subject matches
# RELEASE_MERGE_SUBJECT_REGEX (default: ^chore\(release\): version packages).
# offer-promote-prod is true only when run-changesets-publish is true AND .releases/ has at
# least one open cycle (cycle.yml present, promotedAt absent or empty).
#
# Optional INCLUDE_PR_METADATA=true merges circle_pull_request and circle_pr_number for consumers
# whose continuation pipelines need PR context (CircleCI does not propagate CIRCLE_PULL_REQUEST).
#
# Environment: CIRCLE_SHA1 (required), BASE_REVISION (default master), OUTPUT_PATH (default
# /tmp/pipeline-parameters.json), SAME_BASE_RUN (default true), INCLUDE_PR_METADATA (default false),
# RELEASE_MERGE_SUBJECT_REGEX, RELEASES_DIR (default .releases).
set -euo pipefail

OUTPUT_PATH="${OUTPUT_PATH:-/tmp/pipeline-parameters.json}"
BASE_REVISION="${BASE_REVISION:-master}"
same_base_raw="${SAME_BASE_RUN:-true}"
SAME_BASE_RUN_LOWER=$(printf '%s' "$same_base_raw" | tr '[:upper:]' '[:lower:]')
include_pr_metadata_raw="${INCLUDE_PR_METADATA:-false}"
INCLUDE_PR_METADATA_LOWER=$(printf '%s' "$include_pr_metadata_raw" | tr '[:upper:]' '[:lower:]')
RELEASES_DIR="${RELEASES_DIR:-.releases}"
RELEASE_MERGE_SUBJECT_REGEX="${RELEASE_MERGE_SUBJECT_REGEX:-^chore\\(release\\): version packages}"

include_pr_metadata_enabled() {
  [[ "$INCLUDE_PR_METADATA_LOWER" == "true" ]] || [[ "$include_pr_metadata_raw" == "1" ]]
}

# Open cycle: .releases/<YYYY.MM.DD.N>/cycle.yml exists and promotedAt is absent/empty.
has_open_release_cycle() {
  local cycle_dir cycle_id cycle_yml
  [[ -d "$RELEASES_DIR" ]] || return 1
  shopt -s nullglob
  for cycle_dir in "$RELEASES_DIR"/*/; do
    cycle_id=$(basename "$cycle_dir")
    [[ "$cycle_id" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]] || continue
    cycle_yml="${cycle_dir}cycle.yml"
    [[ -f "$cycle_yml" ]] || continue
    if grep -Eq '^promotedAt:[[:space:]]*[^[:space:]#]' "$cycle_yml"; then
      continue
    fi
    shopt -u nullglob
    return 0
  done
  shopt -u nullglob
  return 1
}

subject_matches_release_merge() {
  local subject
  subject=$(git show -s --format=%s "$CIRCLE_SHA1")
  [[ "$subject" =~ $RELEASE_MERGE_SUBJECT_REGEX ]]
}

write_pipeline_parameters() {
  local publish_bool="$1"
  local offer_bool="$2"
  local json
  json=$(
    jq -nc \
      --argjson publish "$publish_bool" \
      --argjson offer "$offer_bool" \
      '{"run-changesets-publish": $publish, "offer-promote-prod": $offer}'
  )

  if include_pr_metadata_enabled; then
    local pull_request="${CIRCLE_PULL_REQUEST:-}"
    local pr_number="${CIRCLE_PR_NUMBER:-}"
    if [[ -z "$pr_number" && -n "$pull_request" ]]; then
      pr_number="${pull_request##*/}"
    fi
    json=$(
      jq -c --arg pull_request "$pull_request" --arg pr_number "$pr_number" \
        '. + {circle_pull_request: $pull_request, circle_pr_number: $pr_number}' <<<"$json"
    )
  fi

  if [[ -f "$OUTPUT_PATH" ]]; then
    json=$(jq -cs '.[0] * .[1]' "$OUTPUT_PATH" <(printf '%s' "$json"))
  fi

  printf '%s\n' "$json" >"$OUTPUT_PATH"
}

write_both_false() {
  write_pipeline_parameters false false
}

: "${CIRCLE_SHA1:?CIRCLE_SHA1 is required}"

git fetch origin "$BASE_REVISION"

MERGE_BASE=""
if ! MERGE_BASE=$(git merge-base "origin/${BASE_REVISION}" "$CIRCLE_SHA1" 2>/dev/null) || [[ -z "$MERGE_BASE" ]]; then
  if [[ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo false)" == "true" ]]; then
    git fetch --unshallow origin 2>/dev/null || true
  else
    git fetch --deepen=1 origin 2>/dev/null || true
  fi
fi
if ! MERGE_BASE=$(git merge-base "origin/${BASE_REVISION}" "$CIRCLE_SHA1" 2>/dev/null) || [[ -z "$MERGE_BASE" ]]; then
  write_both_false
  echo "Unable to compute merge-base for origin/${BASE_REVISION} and ${CIRCLE_SHA1}: wrote false flags to ${OUTPUT_PATH}" >&2
  exit 0
fi

if [[ "$MERGE_BASE" == "$CIRCLE_SHA1" ]]; then
  if [[ "$SAME_BASE_RUN_LOWER" != "true" ]] && [[ "$same_base_raw" != "1" ]]; then
    write_both_false
    echo "Same revision as base (SAME_BASE_RUN disallows same-base run): wrote false flags to ${OUTPUT_PATH}"
    exit 0
  fi
  PREVIOUS_REVISION=""
  if git rev-parse "${CIRCLE_SHA1}~1" >/dev/null 2>&1; then
    PREVIOUS_REVISION=$(git rev-parse "${CIRCLE_SHA1}~1")
  else
    if [[ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo false)" == "true" ]]; then
      git fetch --unshallow origin 2>/dev/null || true
    else
      git fetch --deepen=1 origin 2>/dev/null || true
    fi
    if git rev-parse "${CIRCLE_SHA1}~1" >/dev/null 2>&1; then
      PREVIOUS_REVISION=$(git rev-parse "${CIRCLE_SHA1}~1")
    else
      write_both_false
      echo "Unable to resolve previous revision for ${CIRCLE_SHA1}: wrote false flags to ${OUTPUT_PATH}" >&2
      exit 0
    fi
  fi
  MERGE_BASE="$PREVIOUS_REVISION"
fi

echo "Comparing ${MERGE_BASE}..${CIRCLE_SHA1} for release-related paths"

FILES_CHANGED=$(git -c core.quotepath=false diff --name-only "$MERGE_BASE" "$CIRCLE_SHA1")

path_signal=false

while IFS= read -r file; do
  [[ -z "${file:-}" ]] && continue
  if [[ "$file" =~ CHANGELOG\.md$ ]]; then
    path_signal=true
    echo "Changelog change: $file"
    break
  fi
done <<<"$FILES_CHANGED"

if [[ "$path_signal" != "true" ]]; then
  while IFS= read -r file; do
    [[ -z "${file:-}" ]] && continue
    [[ "$file" == *package.json ]] || continue
    if ! git cat-file -e "${CIRCLE_SHA1}:${file}" 2>/dev/null; then
      continue
    fi
    new=$(git show "${CIRCLE_SHA1}:${file}" | jq -r '.version // empty')
    if git cat-file -e "${MERGE_BASE}:${file}" 2>/dev/null; then
      old=$(git show "${MERGE_BASE}:${file}" | jq -r '.version // empty')
    else
      old=""
    fi
    if [[ "$old" != "$new" ]]; then
      path_signal=true
      echo "Version field change in ${file}: '${old}' -> '${new}'"
      break
    fi
  done <<<"$FILES_CHANGED"
fi

publish=false
offer=false

if [[ "$path_signal" == "true" ]] && subject_matches_release_merge; then
  publish=true
  if has_open_release_cycle; then
    offer=true
  fi
fi

write_pipeline_parameters "$publish" "$offer"

echo "Wrote $(cat "$OUTPUT_PATH") to ${OUTPUT_PATH}"
