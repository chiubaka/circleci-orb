#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "uses stable changelog formatter when STABLE_RELEASE_NOTES_CHANGELOG_PATHS is set" {
  local work
  work="${BATS_TEST_TMPDIR}/stable-notes"
  mkdir -p "$work/.releases/2026.05.08.1/rc1" "$work/apps/server"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1/cycle.yml" \
    "$work/.releases/2026.05.08.1/cycle.yml"
  printf '%s\n' "_rc snapshot_" >"$work/.releases/2026.05.08.1/rc1/release-notes.md"
  printf '%s\n' '{"name":"@t/server","version":"5.1.0"}' >"$work/apps/server/package.json"
  cat >"$work/apps/server/CHANGELOG.md" <<'CHANGELOG'
# @t/server
## 5.1.0
### Bug Fixes
- Fix: Handle empty export queue
CHANGELOG

  cd "$work" || exit 1
  run env \
    STABLE_RELEASE_NOTES_CHANGELOG_PATHS="apps/server/CHANGELOG.md" \
    FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/formatChangesetsBatchReleaseNotes.mjs" \
    CHANGESET_CATEGORY_PREFIXES_SCRIPT="$PROJECT_ROOT/src/scripts/changesetCategoryPrefixes.mjs" \
    RELEASE_NOTES_GROUPING=category \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    node "$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" ".releases/2026.05.08.1"
  assert_success

  run grep -F '`@t/server@5.1.0`' ".releases/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "## 2026.05.08.1-rc1" ".releases/2026.05.08.1/release-notes.md"
  assert_failure
  run grep -F "promotedAt:" ".releases/2026.05.08.1/cycle.yml"
  assert_success
}

@test "rolls up rc notes when STABLE_RELEASE_NOTES_CHANGELOG_PATHS is unset" {
  local work
  work="${BATS_TEST_TMPDIR}/rollup-notes"
  mkdir -p "$work/.releases"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/.releases/"

  cd "$work" || exit 1
  run env -u STABLE_RELEASE_NOTES_CHANGELOG_PATHS \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    node "$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" ".releases/2026.05.08.1"
  assert_success

  run grep -F "### @chiubaka/server" ".releases/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "## 2026.05.08.1-rc1" ".releases/2026.05.08.1/release-notes.md"
  assert_failure
}
