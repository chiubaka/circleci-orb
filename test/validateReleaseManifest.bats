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
}

@test "rejects flat legacy manifest path" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml"
  assert_failure
  assert_output --partial "flat .releases/<id>.yml"
}

@test "rejects deploy key in rc manifest" {
  work="${BATS_TEST_TMPDIR}/invalid-rc-manifest"
  mkdir -p "$work/rc1"
  cat >"$work/rc1/manifest.yml" <<'EOF'
release: 2026.05.08.1
rc: 1
cutAt: 2026-05-08T14:32:00Z
deploy: []
artifacts:
  server: server-v5.1.0
EOF
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" "$work/rc1/manifest.yml"
  assert_failure
  assert_output --partial "deploy"
}
