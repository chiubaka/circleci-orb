#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "refreshes Published versions from STABLE_PACKAGE_VERSIONS after rollup" {
  local work
  work="${BATS_TEST_TMPDIR}/stable-notes"
  mkdir -p "$work/.releases"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/.releases/"
  cat >"$work/.releases/2026.05.08.1/rc1/release-notes.md" <<'RC_NOTES'
### @t/server

#### Bug Fixes

- Handle empty export queue

## Published versions

- `@t/server@5.1.0-rc.1`
- `@t/web@2.3.0-rc.1`
RC_NOTES

  cd "$work" || exit 1
  run env \
    STABLE_PACKAGE_VERSIONS="@t/server=5.1.0,@t/web=2.3.0,@t/lib=1.0.0" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    node "$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" ".releases/2026.05.08.1"
  assert_success

  run grep -F '`@t/server@5.1.0`' ".releases/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F '`@t/web@2.3.0`' ".releases/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F '@t/lib' ".releases/2026.05.08.1/release-notes.md"
  assert_failure
  run grep -F -- '-rc.' ".releases/2026.05.08.1/release-notes.md"
  assert_failure
  run grep -F "promotedAt:" ".releases/2026.05.08.1/cycle.yml"
  assert_success
}

@test "rolls up rc notes when STABLE_PACKAGE_VERSIONS is unset" {
  local work
  work="${BATS_TEST_TMPDIR}/rollup-notes"
  mkdir -p "$work/.releases"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/.releases/"

  cd "$work" || exit 1
  run env -u STABLE_PACKAGE_VERSIONS \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    node "$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" ".releases/2026.05.08.1"
  assert_success

  run grep -F "### @chiubaka/server" ".releases/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "## 2026.05.08.1-rc1" ".releases/2026.05.08.1/release-notes.md"
  assert_failure
}
