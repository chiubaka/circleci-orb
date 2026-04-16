#! /usr/bin/env bash
# Squash-merge subject prefix gate + optional .changeset deletion check. See docs/plans/orb-release-and-registry-workflows.md.
set -euo pipefail

subject=${COMMIT_SUBJECT_OVERRIDE:-}
if [[ -z "$subject" ]]; then
  subject=$(git log -1 --pretty=%s)
fi

regex=${RELEASE_MERGE_SUBJECT_REGEX:-"^chore\\(release\\): version packages"}

if [[ ! "$subject" =~ $regex ]]; then
  echo "assertReleaseMerge: HEAD commit subject does not match the release-merge pattern." >&2
  echo "  subject: $subject" >&2
  echo "  expected ERE (RELEASE_MERGE_SUBJECT_REGEX): $regex" >&2
  exit 1
fi

verify_deletions=${VERIFY_CHANGESET_DELETIONS:-false}
verify_lower=$(printf '%s' "$verify_deletions" | tr '[:upper:]' '[:lower:]')
if [[ "$verify_lower" == "true" ]] || [[ "$verify_lower" == "1" ]]; then
  if ! git show --pretty=format: --name-status HEAD | grep -qE '^D\s+\.changeset/'; then
    echo "assertReleaseMerge: VERIFY_CHANGESET_DELETIONS is true but HEAD has no deleted paths under .changeset/." >&2
    exit 1
  fi
fi
