#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "valid manifest passes validation" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml"
  assert_success
  assert_output --partial "RELEASE_ID=2026.05.08.1"
  assert_output --partial "ARTIFACTS_JSON="
}

@test "rejects deploy key" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-manifests/invalid-deploy-key.yml"
  assert_failure
  assert_output --partial "deploy"
}

@test "rejects filename stem mismatch" {
  run node "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    "$PROJECT_ROOT/test/fixtures/release-manifests/invalid-stem-mismatch.yml"
  assert_failure
  assert_output --partial "filename stem"
}
