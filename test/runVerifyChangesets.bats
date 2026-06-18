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

@test "require-changeset-category-prefix fails when changed changeset lacks prefix" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-bad-prefix"
  mkdir -p "${repo_dir}/.changeset"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  cat >.changeset/base.md <<'EOF'
---
"@t/pkg": patch
---
Feature: base
EOF
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  cat >.changeset/new-change.md <<'EOF'
---
"@t/pkg": patch
---
Missing prefix headline
EOF
  git add .changeset/new-change.md
  git commit -m "add bad changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  REQUIRE_CHANGESET_CATEGORY_PREFIX=true \
  run runVerifyChangesets.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 0
  assert_output --partial "invalid changeset category prefix"
}

@test "require-changeset-category-prefix runs when verify-script is set" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-bad-prefix-custom-verify"
  mkdir -p "${repo_dir}/.changeset"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  cat >.changeset/base.md <<'EOF'
---
"@t/pkg": patch
---
Feature: base
EOF
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  cat >.changeset/new-change.md <<'EOF'
---
"@t/pkg": patch
---
Missing prefix headline
EOF
  git add .changeset/new-change.md
  git commit -m "add bad changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT=changeset:check \
  PRIMARY_BRANCH=master \
  REQUIRE_CHANGESET_CATEGORY_PREFIX=true \
  run runVerifyChangesets.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 0
  assert_output --partial "invalid changeset category prefix"
}

@test "require-changeset-category-prefix rejects unknown prefix tokens" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-unknown-prefix"
  mkdir -p "${repo_dir}/.changeset"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  cat >.changeset/base.md <<'EOF'
---
"@t/pkg": patch
---
Feature: base
EOF
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  cat >.changeset/new-change.md <<'EOF'
---
"@t/pkg": patch
---
Changelog: not a valid prefix
EOF
  git add .changeset/new-change.md
  git commit -m "add bad changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  REQUIRE_CHANGESET_CATEGORY_PREFIX=true \
  run runVerifyChangesets.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 0
  assert_output --partial "invalid changeset category prefix"
}

@test "require-changeset-category-prefix passes Security prefix" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-security-prefix"
  mkdir -p "${repo_dir}/.changeset"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  cat >.changeset/base.md <<'EOF'
---
"@t/pkg": patch
---
Feature: base
EOF
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  cat >.changeset/new-change.md <<'EOF'
---
"@t/pkg": patch
---
Security: Patch CVE-2026-1234
EOF
  git add .changeset/new-change.md
  git commit -m "add security changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  REQUIRE_CHANGESET_CATEGORY_PREFIX=true \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
}

@test "require-changeset-category-prefix passes when changed changeset has prefix" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-good-prefix"
  mkdir -p "${repo_dir}/.changeset"
  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  cat >.changeset/base.md <<'EOF'
---
"@t/pkg": patch
---
Feature: base
EOF
  git add .changeset/base.md
  git commit -m "base" >/dev/null
  git checkout -b feature >/dev/null
  cat >.changeset/new-change.md <<'EOF'
---
"@t/pkg": patch
---
Fix: Correct rendering
EOF
  git add .changeset/new-change.md
  git commit -m "add good changeset" >/dev/null

  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  PRIMARY_BRANCH=master \
  REQUIRE_CHANGESET_CATEGORY_PREFIX=true \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "exec changeset status"
}
