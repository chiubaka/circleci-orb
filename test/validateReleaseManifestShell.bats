#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "shell wrapper exports multi-artifact JSON without eval breakage" {
  run bash -c '
    # shellcheck disable=SC1091
    source "$1/src/scripts/validateReleaseManifest.sh"
    VALIDATE_RELEASE_MANIFEST_SOURCE_ONLY=true
    run_validate_release_manifest "$1/test/fixtures/release-manifests/2026.05.08.1.yml"
    printf "RELEASE_ID=%s\nARTIFACTS_JSON=%s\n" "$RELEASE_ID" "$ARTIFACTS_JSON"
  ' bash "$PROJECT_ROOT"
  assert_success
  assert_output --partial 'RELEASE_ID=2026.05.08.1'
  assert_output --partial '"server":"server-v5.1.0"'
  assert_output --partial '"web":"web-v2.3.0"'
}
