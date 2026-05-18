#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "empty promotion-tag-prefix is a no-op" {
  run env PROMOTION_TAG_PREFIX= bash "$PROJECT_ROOT/src/scripts/pushPromotionTag.sh"
  assert_success
  assert_output --partial "skipping"
}

@test "fails when prefix set but no manifest on commit" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main >/dev/null 2>&1
  git config user.email test@test
  git config user.name Test
  echo x >README.md
  git add README.md && git commit -m init >/dev/null 2>&1
  run env GITHUB_TOKEN=fake PROMOTION_TAG_PREFIX=staging \
    bash "$PROJECT_ROOT/src/scripts/pushPromotionTag.sh"
  assert_failure
  assert_output --partial "no manifest"
}
