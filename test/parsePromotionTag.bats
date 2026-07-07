#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
  PARSE_PROMOTION_TAG_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/parsePromotionTag.sh"
  export -f parse_promotion_tag_main
}

@test "parses staging promotion tag with rc suffix" {
  run env TAG=staging-2026.04.06.1-rc2 bash -c 'parse_promotion_tag_main'
  assert_success
  assert_output --partial "PROMOTION_ENV=staging"
  assert_output --partial "RELEASE_ID=2026.04.06.1"
  assert_output --partial "RC_INDEX=2"
}

@test "parses prod promotion tag without rc suffix" {
  run env TAG=prod-2026.04.06.2 bash -c 'parse_promotion_tag_main'
  assert_success
  assert_output --partial "PROMOTION_ENV=prod"
  assert_output --partial "RELEASE_ID=2026.04.06.2"
  refute_output --partial "RC_INDEX="
}

@test "fails on legacy staging tag without rc suffix" {
  run env TAG=staging-2026.04.06.1 bash -c 'parse_promotion_tag_main'
  assert_failure
  assert_output --partial "staging-<cycle-id>-rc<n>"
}

@test "fails on artifact-style tag" {
  run env TAG=server-v1.2.3 bash -c 'parse_promotion_tag_main'
  assert_failure
  assert_output --partial "staging-<cycle-id>-rc<n>"
}
