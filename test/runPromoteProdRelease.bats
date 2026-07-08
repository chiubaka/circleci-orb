#! /usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/setup"
  _setup
}

_promote_prod_init_clone() {
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
  mkdir -p "${clone}/.releases"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "${clone}/.releases/"
  echo base >"${clone}/README.md"
  git -C "$clone" add .
  git -C "$clone" commit -m "rc1 release cycle" >/dev/null 2>&1
  git -C "$clone" branch -M master >/dev/null 2>&1
  git -C "$clone" push -u origin master >/dev/null 2>&1
  printf '%s' "$clone"
}

_write_gh_stub() {
  local bindir gh_stub
  bindir=$(mktemp -d)
  gh_stub="${bindir}/gh"
  cat >"$gh_stub" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "release" && "$2" == "view" ]]; then
  exit 1
fi
printf '%s\0' "$*" >>"${GH_CALL_LOG:?GH_CALL_LOG must be set}"
exit 0
EOF
  chmod +x "$gh_stub"
  printf '%s' "$bindir"
}

@test "default finalize mode tags prod release at finalize commit" {
  local clone bindir gh_call_log validated_sha finalize_sha tag_sha args
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  run env GITHUB_TOKEN=fake \
    GITHUB_REPO_SLUG=example/test \
    PRIMARY_BRANCH=master \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    FINALIZE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" \
    RESOLVE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/resolveReleaseCycleOnCommit.mjs" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    GH_CALL_LOG="$gh_call_log" \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runPromoteProdRelease.sh"

  assert_success
  finalize_sha=$(git rev-parse HEAD)
  [[ "$finalize_sha" != "$validated_sha" ]]

  tag_sha=$(git rev-parse "prod-2026.05.08.1^{commit}")
  assert_equal "$finalize_sha" "$tag_sha"
  [[ "$validated_sha" != "$tag_sha" ]]

  args=$(tr '\0' ' ' <"$gh_call_log")
  [[ "$args" == *"release create"* ]] || false
  [[ "$args" == *"--target ${finalize_sha}"* ]]
  [[ "$args" != *"--target ${validated_sha}"* ]]
}

@test "validated mode tags prod release at pre-finalize commit" {
  local clone bindir gh_call_log validated_sha finalize_sha tag_sha args
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  run env GITHUB_TOKEN=fake \
    GITHUB_REPO_SLUG=example/test \
    PRIMARY_BRANCH=master \
    TAG_TARGET=validated \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    FINALIZE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" \
    RESOLVE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/resolveReleaseCycleOnCommit.mjs" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    GH_CALL_LOG="$gh_call_log" \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runPromoteProdRelease.sh"

  assert_success
  finalize_sha=$(git rev-parse HEAD)
  [[ "$finalize_sha" != "$validated_sha" ]]

  tag_sha=$(git rev-parse "prod-2026.05.08.1^{commit}")
  assert_equal "$validated_sha" "$tag_sha"
  [[ "$finalize_sha" != "$tag_sha" ]]

  args=$(tr '\0' ' ' <"$gh_call_log")
  [[ "$args" == *"release create"* ]] || false
  [[ "$args" == *"--target ${validated_sha}"* ]]
  [[ "$args" != *"--target ${finalize_sha}"* ]]

  run git show "${finalize_sha}:.releases/2026.05.08.1/cycle.yml"
  assert_success
  assert_output --partial "promotedAt:"
}

@test "validated mode still pushes finalize artifacts to primary branch" {
  local clone bindir gh_call_log validated_sha
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  run env GITHUB_TOKEN=fake \
    GITHUB_REPO_SLUG=example/test \
    PRIMARY_BRANCH=master \
    TAG_TARGET=validated \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    FINALIZE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" \
    RESOLVE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/resolveReleaseCycleOnCommit.mjs" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    GH_CALL_LOG="$gh_call_log" \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runPromoteProdRelease.sh"

  assert_success

  git fetch origin master >/dev/null 2>&1

  run git show "origin/master:.releases/2026.05.08.1/cycle.yml"
  assert_success
  assert_output --partial "promotedAt:"

  run git rev-parse "origin/master^{commit}"
  assert_success
  [[ "$validated_sha" != "$output" ]]
}

@test "rejects unknown tag-target value" {
  local clone bindir gh_call_log
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  cd "$clone" || exit 1

  run env GITHUB_TOKEN=fake \
    GITHUB_REPO_SLUG=example/test \
    PRIMARY_BRANCH=master \
    RELEASE_ID=2026.05.08.1 \
    TAG_TARGET=unknown \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    FINALIZE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" \
    RESOLVE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/resolveReleaseCycleOnCommit.mjs" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    GH_CALL_LOG="$gh_call_log" \
    PATH="${bindir}:$PATH" \
    bash "$PROJECT_ROOT/src/scripts/runPromoteProdRelease.sh"

  assert_failure
  assert_output --partial "TAG_TARGET must be finalize or validated"
}
