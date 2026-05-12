load '../helpers/setup'

setup() {
  _setup
  FIXTURE_MONOREPO="$PROJECT_ROOT/test/fixtures/changesets-publishing/minimal-monorepo"
  export FIXTURE_MONOREPO
  CHANGESETS_RELEASE_PR_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  export -f count_pending_changesets pkg_at_version build_title extract_changelog_top build_pr_body_file
}

@test "integration: fixture monorepo has one pending changeset file" {
  cp -a "$FIXTURE_MONOREPO" "$BATS_TEST_TMPDIR/ws"
  cd "$BATS_TEST_TMPDIR/ws" || exit 1

  n=$(count_pending_changesets)
  assert_equal "$n" "1"
}

@test "integration: fixture monorepo produces alphabetical release title after simulated version bumps" {
  cp -a "$FIXTURE_MONOREPO" "$BATS_TEST_TMPDIR/ws"
  cd "$BATS_TEST_TMPDIR/ws" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  git add .
  git commit -m "init fixture"

  printf '%s\n' '{"name":"@fixture/lib","version":"0.2.0"}' >packages/lib/package.json

  title=$(build_title)
  assert_equal "$title" 'chore(release): version packages (@fixture/lib@0.2.0)'
}

@test "integration: assertReleaseMerge with VERIFY_CHANGESET_DELETIONS using fixture-shaped tree" {
  cp -a "$FIXTURE_MONOREPO" "$BATS_TEST_TMPDIR/ws"
  cd "$BATS_TEST_TMPDIR/ws" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  git add .
  git commit -m "init"
  git rm .changeset/fixture-change.md
  git commit -m "chore(release): version packages (@fixture/lib@0.2.0)"

  VERIFY_CHANGESET_DELETIONS=true run assertReleaseMerge.sh

  assert_success
}

@test "integration: packed orb includes changesets publishing commands and jobs" {
  if ! command -v circleci >/dev/null 2>&1; then
    skip "circleci CLI not available (install: https://circleci.com/docs/guides/toolkit/local-cli/)"
  fi

  run circleci orb pack "$PROJECT_ROOT/src"
  assert_success
  assert_output --partial "changesets-release-pr:"
  assert_output --partial "changesets-gated-publish:"
  assert_output --partial "assert-release-merge:"
  assert_output --partial "install-github-cli:"
  assert_output --partial "github-release-train:"
}
