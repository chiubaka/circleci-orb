#!/usr/bin/env bash
# Emit JSON {"run-changesets-publish": true|false} (default path below) for continuation parameters
# and for the push-orb-version-tag pre-step gate (see .circleci/continue_config.yml).
# Mirrors merge-base / same-revision behavior from circleci/path-filtering create-parameters.sh,
# but sets the flag only when:
#   - any CHANGELOG.md path changed in the diff, or
#   - any package.json had its top-level "version" field value change (including new files).
#
# Environment: CIRCLE_SHA1 (required), BASE_REVISION (default master), OUTPUT_PATH (default
# /tmp/pipeline-parameters.json), SAME_BASE_RUN (default true).
set -euo pipefail

OUTPUT_PATH="${OUTPUT_PATH:-/tmp/pipeline-parameters.json}"
BASE_REVISION="${BASE_REVISION:-master}"
same_base_raw="${SAME_BASE_RUN:-true}"
SAME_BASE_RUN_LOWER=$(printf '%s' "$same_base_raw" | tr '[:upper:]' '[:lower:]')

: "${CIRCLE_SHA1:?CIRCLE_SHA1 is required}"

git fetch origin "$BASE_REVISION"

MERGE_BASE=""
if ! MERGE_BASE=$(git merge-base "origin/${BASE_REVISION}" "$CIRCLE_SHA1" 2>/dev/null) || [[ -z "$MERGE_BASE" ]]; then
  echo '{"run-changesets-publish": false}' >"$OUTPUT_PATH"
  echo "Unable to compute merge-base for origin/${BASE_REVISION} and ${CIRCLE_SHA1}: wrote false to ${OUTPUT_PATH}" >&2
  exit 0
fi

if [[ "$MERGE_BASE" == "$CIRCLE_SHA1" ]]; then
  if [[ "$SAME_BASE_RUN_LOWER" != "true" ]] && [[ "$same_base_raw" != "1" ]]; then
    echo '{"run-changesets-publish": false}' >"$OUTPUT_PATH"
    echo "Same revision as base (SAME_BASE_RUN disallows same-base run): wrote false to ${OUTPUT_PATH}"
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
      echo '{"run-changesets-publish": false}' >"$OUTPUT_PATH"
      echo "Unable to resolve previous revision for ${CIRCLE_SHA1}: wrote false to ${OUTPUT_PATH}" >&2
      exit 0
    fi
  fi
  MERGE_BASE="$PREVIOUS_REVISION"
fi

echo "Comparing ${MERGE_BASE}..${CIRCLE_SHA1} for release-related paths"

FILES_CHANGED=$(git -c core.quotepath=false diff --name-only "$MERGE_BASE" "$CIRCLE_SHA1")

publish=false

while IFS= read -r file; do
  [[ -z "${file:-}" ]] && continue
  if [[ "$file" =~ CHANGELOG\.md$ ]]; then
    publish=true
    echo "Changelog change: $file"
    break
  fi
done <<<"$FILES_CHANGED"

if [[ "$publish" != "true" ]]; then
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
      publish=true
      echo "Version field change in ${file}: '${old}' -> '${new}'"
      break
    fi
  done <<<"$FILES_CHANGED"
fi

if [[ "$publish" == "true" ]]; then
  echo '{"run-changesets-publish": true}' >"$OUTPUT_PATH"
else
  echo '{"run-changesets-publish": false}' >"$OUTPUT_PATH"
fi

echo "Wrote $(cat "$OUTPUT_PATH") to ${OUTPUT_PATH}"
