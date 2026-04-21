setup() {
  load "helpers/setup"
  _setup
}

@test "runs pnpm exec changeset status when VERIFY_SCRIPT is empty" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-default"
  mkdir -p "${repo_dir}"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .changeset
  printf "base\n" > .changeset/base.md
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  printf "update\n" > .changeset/base.md
  git add .changeset/base.md
  git commit -m "touch changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "exec changeset status"
}

@test "runs pnpm run when verify-script is set" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT=changeset:check \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_args "${mock}")" "run changeset:check"
}

@test "fails when branch does not touch a changeset markdown file" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-no-changeset-touch"
  mkdir -p "${repo_dir}"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .changeset
  printf "base\n" > .changeset/base.md
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  printf "readme\n" > README.md
  git add README.md
  git commit -m "docs" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  run runVerifyChangesets.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 0
  assert_output --partial "must add or modify a .changeset/*.md file"
}

@test "fails with clear error when merge-base cannot be determined" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-no-primary-branch"
  mkdir -p "${repo_dir}"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf "readme\n" > README.md
  git add README.md
  git commit -m "base" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=does-not-exist \
  run runVerifyChangesets.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 0
  assert_output --partial "could not determine merge-base"
}
