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

@test "rejects unpromoted cycle missing cycle release-notes.md" {
  work="${BATS_TEST_TMPDIR}/missing-cycle-notes"
  mkdir -p "$work"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/"
  rm -f "$work/2026.05.08.1/release-notes.md"

  run node "$PROJECT_ROOT/src/scripts/validateReleaseCycle.mjs" \
    "$work/2026.05.08.1"
  assert_failure
  assert_output --partial "missing release-notes.md"
}

@test "rollup collates RC notes without RC headings" {
  work="${BATS_TEST_TMPDIR}/rollup-cycle"
  mkdir -p "$work"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "$work/"

  run node "$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" "$work/2026.05.08.1"
  assert_success
  assert [ -f "$work/2026.05.08.1/release-notes.md" ]
  run grep -F "### @chiubaka/server" "$work/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "#### Bug Fixes" "$work/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "## 2026.05.08.1-rc1" "$work/2026.05.08.1/release-notes.md"
  assert_failure

  mkdir -p "$work/2026.05.08.1/rc2"
  cat >"$work/2026.05.08.1/rc2/release-notes.md" <<'EOF'
### @chiubaka/server

#### Features

- Add soak patch feature

#### Bug Fixes

- Fix export queue handling

## Published versions

- `@chiubaka/server@1.2.4`
EOF
  run node "$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" "$work/2026.05.08.1"
  assert_success
  run grep -F "#### Features" "$work/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "Add soak patch feature" "$work/2026.05.08.1/release-notes.md"
  assert_success
  run grep -F "Fix export queue handling" "$work/2026.05.08.1/release-notes.md"
  assert_success
  # Repeated rc1 bullet must appear exactly once after collation.
  run bash -c "grep -cF 'Fix export queue handling' '$work/2026.05.08.1/release-notes.md'"
  assert_output "1"
  run grep -F "## 2026.05.08.1-rc2" "$work/2026.05.08.1/release-notes.md"
  assert_failure
  run grep -F '@chiubaka/server@1.2.4' "$work/2026.05.08.1/release-notes.md"
  assert_success
  # Later RC published pin supersedes the earlier one.
  run grep -F '@chiubaka/server@1.2.3' "$work/2026.05.08.1/release-notes.md"
  assert_failure
}

@test "rollup fails when rc notes contain unparsed content" {
  work="${BATS_TEST_TMPDIR}/rollup-unparsed"
  mkdir -p "$work/2026.05.08.1/rc1"
  printf 'release: 2026.05.08.1\nopenedAt: 2026-05-08T00:00:00Z\n' \
    >"$work/2026.05.08.1/cycle.yml"
  cat >"$work/2026.05.08.1/rc1/release-notes.md" <<'EOF'
### @chiubaka/server

#### Bug Fixes

This prose is not a bullet and must not be silently dropped.

- Fix export queue handling
EOF
  run node "$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" "$work/2026.05.08.1"
  assert_failure
  assert_output --partial "unparsed"
  assert_output --partial "This prose is not a bullet"
}
