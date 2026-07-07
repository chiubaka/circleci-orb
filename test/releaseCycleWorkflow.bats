#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "valid rc manifest passes validation" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1/rc1/manifest.yml"
  assert_success
  assert_output --partial "RELEASE_ID=2026.05.08.1"
  assert_output --partial "RC_INDEX=1"
  assert_output --partial "ARTIFACTS_JSON="
}

@test "rejects flat legacy manifest path" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml"
  assert_failure
  assert_output --partial "flat .releases/<id>.yml"
}

@test "validates release cycle directory" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseCycle.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1"
  assert_success
  assert_output --partial "RELEASE_ID=2026.05.08.1"
  assert_output --partial "RC_COUNT=1"
}

@test "rollup writes release-notes.md with rc headings" {
  work="${BATS_TEST_TMPDIR}/rollup-cycle"
  mkdir -p "$work"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/"

  run node "$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" "$work/2026.05.08.1"
  assert_success
  assert [ -f "$work/2026.05.08.1/release-notes.md" ]
  run grep -F "## 2026.05.08.1-rc1" "$work/2026.05.08.1/release-notes.md"
  assert_success

  mkdir -p "$work/2026.05.08.1/rc2"
  cp "$work/2026.05.08.1/rc1/notes.md" "$work/2026.05.08.1/rc2/notes.md"
  run node "$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" "$work/2026.05.08.1"
  assert_success
  run grep -F "## 2026.05.08.1-rc2" "$work/2026.05.08.1/release-notes.md"
  assert_success
}
