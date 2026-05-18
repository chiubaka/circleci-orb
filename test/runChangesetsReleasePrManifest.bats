#! /usr/bin/env bats
# Regression: CREATE_RELEASE_MANIFEST=false does not require DEPLOYABLE_PACKAGES.

setup() {
  load "helpers/setup"
  _setup
}

@test "runChangesetsReleasePr script has no unconditional manifest requirement" {
  run grep -n "DEPLOYABLE_PACKAGES" "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  assert_success
  # Requirement only appears inside create-release-manifest branch
  run awk '/create_manifest_lower/{flag=1} flag && /DEPLOYABLE_PACKAGES/{print; exit}' \
    "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  assert_success
  assert_output --partial "DEPLOYABLE_PACKAGES"
}
