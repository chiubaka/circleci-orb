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

@test "rejects promotion-tag-prefix with trailing hyphen" {
  run env GITHUB_TOKEN=fake PROMOTION_TAG_PREFIX=staging--- \
    bash "$PROJECT_ROOT/src/scripts/pushPromotionTag.sh"
  assert_failure
  assert_output --partial "trailing hyphen"
}

@test "fails when prefix set but no manifest on commit" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init >/dev/null 2>&1
  git checkout -b main >/dev/null 2>&1
  git config user.email test@test
  git config user.name Test
  echo x >README.md
  git add README.md && git commit -m init >/dev/null 2>&1
  run env GITHUB_TOKEN=fake PROMOTION_TAG_PREFIX=staging \
    bash "$PROJECT_ROOT/src/scripts/pushPromotionTag.sh"
  assert_failure
  assert_output --partial "no manifest"
}

@test "inlined copy reaches manifest check without lib/trainId.sh sibling" {
  script_dir="${BATS_TEST_TMPDIR}/circleci-push-promotion-inline"
  mkdir -p "$script_dir"
  cp "$PROJECT_ROOT/src/scripts/pushPromotionTag.sh" "$script_dir/pushPromotionTag.sh"

  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main >/dev/null 2>&1
  git config user.email test@test
  git config user.name Test
  echo x >README.md
  git add README.md && git commit -m init >/dev/null 2>&1

  run env GITHUB_TOKEN=fake PROMOTION_TAG_PREFIX=staging \
    bash "${script_dir}/pushPromotionTag.sh"

  assert_failure
  refute_output --partial "lib/trainId.sh"
  assert_output --partial "no manifest"
}
