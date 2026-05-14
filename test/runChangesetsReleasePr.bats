setup() {
  load "helpers/setup"
  _setup
  CHANGESETS_RELEASE_PR_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  export -f count_pending_changesets pkg_at_version build_title extract_changelog_top build_pr_body_file _resolve_formatter_script build_force_with_lease_arg
}

@test "count_pending_changesets is zero without .changeset markdown files" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset

  n=$(count_pending_changesets)
  assert_equal "$n" "0"
}

@test "count_pending_changesets counts non-README markdown under .changeset" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  echo "---" >.changeset/some-change.md
  printf '%s\n' "---" >.changeset/README.md

  n=$(count_pending_changesets)
  assert_equal "$n" "1"
}

@test "count_pending_changesets restores prior nullglob setting" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  shopt -s nullglob
  n=$(count_pending_changesets)
  assert_equal "$n" "0"
  run shopt -p nullglob
  assert_output --partial "-s nullglob"
}

@test "build_title joins sorted unique name@version from changed package.json files" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  mkdir -p packages/b packages/a
  printf '%s\n' '{"name":"@scope/b","version":"2.0.0"}' >packages/b/package.json
  printf '%s\n' '{"name":"@scope/a","version":"1.0.0"}' >packages/a/package.json
  git add . && git commit -m "init"
  printf '%s\n' '{"name":"@scope/b","version":"2.1.0"}' >packages/b/package.json
  printf '%s\n' '{"name":"@scope/a","version":"1.1.0"}' >packages/a/package.json

  title=$(build_title)
  assert_equal "$title" 'chore(release): version packages (@scope/a@1.1.0, @scope/b@2.1.0)'
}

@test "build_title returns non-success when changeset version left no package.json diff" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  printf '%s\n' '{"name":"@scope/a","version":"1.0.0"}' >package.json
  git add . && git commit -m "init"

  run build_title
  assert_failure
}

@test "extract_changelog_top returns first version section body" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  cat >CL.md <<'EOF'
# Changelog
## 2.0.0
### Minor
- hello
## 1.0.0
- old
EOF

  run bash -c 'cd "'"$BATS_TEST_TMPDIR"'" && extract_changelog_top CL.md'
  assert_success
  assert_line --index 0 "### Minor"
  assert_line --index 1 "- hello"
}

@test "build_pr_body_file groups changed changelogs with categories and published versions" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/pkg","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
# @t/pkg
## 1.0.0
- init
EOF
  git add . && git commit -m "init"
  printf '%s\n' '{"name":"@t/pkg","version":"1.2.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
# @t/pkg
## 1.2.0
### Minor
- new entry
EOF

  body=$(mktemp)
  build_pr_body_file "$body"
  run grep -F "### Minor Changes" "$body"
  assert_success
  run grep -F "**@t/pkg**" "$body"
  assert_success
  run grep -F "new entry" "$body"
  assert_success
  run grep -F "## Published versions" "$body"
  assert_success
  run grep -F '`@t/pkg@1.2.0`' "$body"
  assert_success
  run grep -F "Changelog excerpts" "$body"
  assert_failure
  rm -f "$body"
}

@test "build_pr_body_file includes untracked CHANGELOG.md in grouped output" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  printf '%s\n' '{"name":"@t/root","version":"1.1.0"}' >package.json
  git add package.json && git commit -m "init"

  cat >CHANGELOG.md <<'EOF'
# @t/root
## 1.1.0
### Patch Changes
- include untracked changelog excerpt
EOF

  body=$(mktemp)
  build_pr_body_file "$body"
  run grep -F "### Patch Changes" "$body"
  assert_success
  run grep -F "**@t/root**" "$body"
  assert_success
  run grep -F "include untracked changelog excerpt" "$body"
  assert_success
  run grep -F '`@t/root@1.1.0`' "$body"
  assert_success
  rm -f "$body"
}

@test "mktemp EXIT cleanup keeps body_file non-local so trap survives function return (set -u)" {
  # Regression: local body_file + trap 'rm -f "$body_file"' on EXIT — after f returns the
  # local is gone and set -u errors on "unbound variable" when the trap runs.
  run bash -euo pipefail -c '
    f() {
      local x
      x=1
      body_file=$(mktemp)
      trap '\''rm -f "$body_file"'\'' EXIT
    }
    f
    exit 0
  '
  assert_success
}

@test "build_force_with_lease_arg returns sha-pinned lease when remote branch exists" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  printf '%s\n' 'first' >README.md
  git add README.md
  git commit -m "init"

  git clone --bare . remote.git
  git remote add origin "$BATS_TEST_TMPDIR/remote.git"
  git fetch origin main
  remote_sha=$(git rev-parse HEAD)

  run bash -c 'cd "'"$BATS_TEST_TMPDIR"'" && build_force_with_lease_arg "https://github.com/example/repo.git" "main"'
  assert_success
  assert_output "--force-with-lease=main:${remote_sha}"
}

@test "build_force_with_lease_arg returns default lease when remote branch is absent" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  git init -b main
  git config user.email test@test
  git config user.name Test
  printf '%s\n' 'first' >README.md
  git add README.md
  git commit -m "init"

  git clone --bare . remote.git
  git remote add origin "$BATS_TEST_TMPDIR/remote.git"

  run bash -c 'cd "'"$BATS_TEST_TMPDIR"'" && build_force_with_lease_arg "https://github.com/example/repo.git" "release/main"'
  assert_success
  assert_output "--force-with-lease"
}
