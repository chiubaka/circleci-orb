setup() {
  load "helpers/setup"
  _setup
}

@test "accepts squash subject matching default release prefix" {
  COMMIT_SUBJECT_OVERRIDE='chore(release): version packages (@chiubaka/foo@1.0.0)' run assertReleaseMerge.sh

  assert_success
}

@test "rejects subject that does not match default prefix" {
  COMMIT_SUBJECT_OVERRIDE='feat: something' run assertReleaseMerge.sh

  assert_failure
}

@test "custom RELEASE_MERGE_SUBJECT_REGEX is honored" {
  RELEASE_MERGE_SUBJECT_REGEX='^custom:' COMMIT_SUBJECT_OVERRIDE='custom: release' run assertReleaseMerge.sh

  assert_success
}

@test "VERIFY_CHANGESET_DELETIONS passes when HEAD deletes under .changeset" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  echo base >README.md
  git add README.md && git commit -m "init"
  mkdir -p .changeset
  echo "---" >.changeset/pending.md
  git add .changeset/pending.md && git commit -m "add changeset"
  git rm .changeset/pending.md
  git commit -m "chore(release): version packages (@scope/a@1.0.0)"

  VERIFY_CHANGESET_DELETIONS=true run assertReleaseMerge.sh

  assert_success
}

@test "VERIFY_CHANGESET_DELETIONS fails when no .changeset deletions on HEAD" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  echo base >README.md
  git add README.md && git commit -m "init"

  git commit --allow-empty -m "chore(release): version packages (@scope/a@1.0.0)"

  VERIFY_CHANGESET_DELETIONS=true run assertReleaseMerge.sh

  assert_failure
}
