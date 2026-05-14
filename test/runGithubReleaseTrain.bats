#! /usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/setup"
  _setup
}

_source_train_helpers() {
  GITHUB_RELEASE_TRAIN_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"
  export -f regex_escape_basic max_n_from_ls_remote_for_date utc_calendar_date_str apply_title_template
}

# Prints clone directory path to stdout (git noise redirected so command substitution stays clean).
# origin is configured as a github.com URL (for assert-origin) with insteadOf so push/fetch/ls-remote use the bare repo.
_github_train_init_clone() {
  local parent bare clone bare_abs
  parent=$(mktemp -d)
  bare="${parent}/origin.git"
  clone="${parent}/work"
  git init --bare "$bare" >/dev/null 2>&1
  mkdir -p "$clone"
  git -C "$clone" init >/dev/null 2>&1
  git -C "$clone" config user.email test@test
  git -C "$clone" config user.name Test
  bare_abs=$(cd "$(dirname "$bare")" && pwd)/$(basename "$bare")
  git -C "$clone" remote add origin "https://github.com/example/test.git"
  git -C "$clone" config url."file://${bare_abs}".insteadOf "https://github.com/example/test.git"
  echo "base" >"${clone}/README.md"
  git -C "$clone" add README.md
  git -C "$clone" commit -m "init" >/dev/null 2>&1
  git -C "$clone" branch -M master >/dev/null 2>&1
  git -C "$clone" push -u origin master >/dev/null 2>&1
  printf '%s' "$clone"
}

@test "max_n_from_ls_remote_for_date returns 0 when no matching tags" {
  _source_train_helpers
  run bash -c 'printf "%s\n" "deadbeef refs/tags/v1.0.0" | max_n_from_ls_remote_for_date "release/" "2026.05.08"'
  assert_success
  assert_output "0"
}

@test "max_n_from_ls_remote_for_date returns max N for prefix and UTC date" {
  _source_train_helpers
  run bash -c 'printf "%s\n" \
    "a refs/tags/release/2026.05.08.1" \
    "b refs/tags/release/2026.05.08.3^{}" \
    "c refs/tags/release/2026.05.08.2" \
    | max_n_from_ls_remote_for_date "release/" "2026.05.08"'
  assert_success
  assert_output "3"
}

@test "max_n_from_ls_remote_for_date supports empty train-tag-prefix" {
  _source_train_helpers
  run bash -c 'printf "%s\n" "a refs/tags/2099.01.01.7" | max_n_from_ls_remote_for_date "" "2099.01.01"'
  assert_success
  assert_output "7"
}

@test "apply_title_template replaces logical_train_id placeholder" {
  _source_train_helpers
  run bash -c 'apply_title_template "r-{{logical_train_id}}" "2099.01.01.2"'
  assert_success
  assert_output "r-2099.01.01.2"
}

@test "fails when merge diff has no CHANGELOG.md paths" {
  local clone
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  echo "two" >>README.md
  git commit -am "second"
  git push origin master

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"
  assert_failure
  assert_output --partial "no CHANGELOG.md paths"
}

@test "fails when origin is not github.com" {
  local clone
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- x
EOF
  git add . && git commit -m "add changelog" && git push origin master
  git remote set-url origin "https://gitlab.com/example/test.git"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"
  assert_failure
  assert_output --partial "github.com"
}

@test "on-existing-tag=skip exits 0 when train tag already exists at target" {
  local clone sha
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- x
EOF
  git add . && git commit -m "changelog" && git push origin master
  sha=$(git rev-parse HEAD)

  git -c tag.gpgSign=false tag -- "release/2099.01.01.1" "$sha"
  git push origin "refs/tags/release/2099.01.01.1"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 ON_EXISTING_TAG=skip \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"
  assert_success
  assert_output --partial "skipping"
}

@test "on-existing-tag=fail exits non-zero when train tag already exists at target" {
  local clone sha
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- x
EOF
  git add . && git commit -m "changelog" && git push origin master
  sha=$(git rev-parse HEAD)

  git -c tag.gpgSign=false tag -- "release/2099.01.01.1" "$sha"
  git push origin "refs/tags/release/2099.01.01.1"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 ON_EXISTING_TAG=fail \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"
  assert_failure
  assert_output --partial "on-existing-tag=fail"
}

@test "gh release create receives logical id as title and prefixed tag name" {
  local clone bindir gh_mock
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- x
EOF
  git add . && git commit -m "changelog" && git push origin master

  gh_mock="$(mock_create)"
  bindir=$(mktemp -d)
  ln -sf "$gh_mock" "${bindir}/gh"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"

  assert_success
  assert_equal "$(mock_get_call_num "$gh_mock")" "1"
  args=$(mock_get_call_args "$gh_mock" 1)
  [[ "$args" == *"--title"* ]] || false
  [[ "$args" == *"2099.01.01.1"* ]] || false
  [[ "$args" == *"release/2099.01.01.1"* ]] || false
}

@test "compute_next_train_id increments N when remote already has tags for UTC date" {
  local clone bindir gh_mock sha_parent
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- x
EOF
  git add . && git commit -m "changelog v1" && git push origin master
  sha_parent=$(git rev-parse HEAD)

  git -c tag.gpgSign=false tag -- "release/2099.01.01.1" "$sha_parent"
  git push origin "refs/tags/release/2099.01.01.1"

  cat >pkg/CHANGELOG.md <<'EOF'
## 1.1.0
- y
EOF
  git add . && git commit -m "changelog v2" && git push origin master

  gh_mock="$(mock_create)"
  bindir=$(mktemp -d)
  ln -sf "$gh_mock" "${bindir}/gh"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"

  assert_success
  args=$(mock_get_call_args "$gh_mock" 1)
  [[ "$args" == *"release/2099.01.01.2"* ]] || false
  [[ "$args" == *"2099.01.01.2"* ]] || false
}

@test "release-notes-source=body-file uses notes-extra-file without changelog diff" {
  local clone bindir gh_mock notes
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  echo "two" >>README.md
  git commit -am "second"
  git push origin master

  notes=$(mktemp)
  printf '%s\n' "manual body" >"$notes"

  gh_mock="$(mock_create)"
  bindir=$(mktemp -d)
  ln -sf "$gh_mock" "${bindir}/gh"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 \
    RELEASE_NOTES_SOURCE=body-file \
    NOTES_EXTRA_FILE="$notes" \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"

  assert_success
  rm -f "$notes"
}

@test "merge-commit notes use grouped format, minor section, and published versions" {
  local clone bindir gh_mock nf args
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p pkg
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.0.0
- init
EOF
  git add . && git commit -m "add pkg" && git push origin master

  printf '%s\n' '{"name":"@t/a","version":"1.1.0"}' >pkg/package.json
  cat >pkg/CHANGELOG.md <<'EOF'
## 1.1.0
### Minor
- ship it
EOF
  git add . && git commit -m "bump" && git push origin master

  gh_mock="$(mock_create)"
  bindir=$(mktemp -d)
  ln -sf "$gh_mock" "${bindir}/gh"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 GITHUB_RELEASE_TRAIN_KEEP_NOTES_FILE=true \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"

  assert_success
  args=$(mock_get_call_args "$gh_mock" 1)
  nf=$(printf '%s' "$args" | awk '{for(i=1;i<=NF;i++) if($i=="--notes-file"){print $(i+1); exit}}')
  [[ -f "$nf" ]] || false
  run grep -F "ship it" "$nf"
  assert_success
  run grep -F "### Minor Changes" "$nf"
  assert_success
  run grep -F "**@t/a**" "$nf"
  assert_success
  run grep -F "## Published versions" "$nf"
  assert_success
  run grep -F '`@t/a@1.1.0`' "$nf"
  assert_success
  run grep -F "Changelog excerpts" "$nf"
  assert_failure
  rm -f "$nf"
}

@test "merge-commit notes group two packages by change category" {
  local clone bindir gh_mock nf args
  cd "$BATS_TEST_TMPDIR" || exit 1
  clone=$(_github_train_init_clone)
  cd "$clone" || exit 1
  mkdir -p packages/a packages/b
  printf '%s\n' '{"name":"@t/a","version":"1.0.0"}' >packages/a/package.json
  printf '%s\n' '{"name":"@t/b","version":"1.0.0"}' >packages/b/package.json
  cat >packages/a/CHANGELOG.md <<'EOF'
## 1.0.0
- init a
EOF
  cat >packages/b/CHANGELOG.md <<'EOF'
## 1.0.0
- init b
EOF
  git add . && git commit -m "add pkgs" && git push origin master

  printf '%s\n' '{"name":"@t/a","version":"2.0.0"}' >packages/a/package.json
  printf '%s\n' '{"name":"@t/b","version":"1.5.0"}' >packages/b/package.json
  cat >packages/a/CHANGELOG.md <<'EOF'
## 2.0.0
### Minor Changes
- aa: minor line for a
EOF
  cat >packages/b/CHANGELOG.md <<'EOF'
## 1.5.0
### Patch Changes
- bb: patch line for b
EOF
  git add . && git commit -m "release bump" && git push origin master

  gh_mock="$(mock_create)"
  bindir=$(mktemp -d)
  ln -sf "$gh_mock" "${bindir}/gh"

  run env GITHUB_TOKEN=fake UTC_DATE_OVERRIDE=2099.01.01 GITHUB_RELEASE_TRAIN_KEEP_NOTES_FILE=true \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runGithubReleaseTrain.sh"

  assert_success
  args=$(mock_get_call_args "$gh_mock" 1)
  nf=$(printf '%s' "$args" | awk '{for(i=1;i<=NF;i++) if($i=="--notes-file"){print $(i+1); exit}}')
  [[ -f "$nf" ]] || false
  run grep -F "### Minor Changes" "$nf"
  assert_success
  run grep -F "**@t/a**" "$nf"
  assert_success
  run grep -F "minor line for a" "$nf"
  assert_success
  run grep -F "### Patch Changes" "$nf"
  assert_success
  run grep -F "**@t/b**" "$nf"
  assert_success
  run grep -F "patch line for b" "$nf"
  assert_success
  run grep -F '`@t/a@2.0.0`' "$nf"
  assert_success
  run grep -F '`@t/b@1.5.0`' "$nf"
  assert_success
  rm -f "$nf"
}
