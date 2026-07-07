#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

_init_git_with_origin() {
  local parent bare clone
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
  echo base >"${clone}/README.md"
  git -C "$clone" add README.md
  git -C "$clone" commit -m init >/dev/null 2>&1
  git -C "$clone" branch -M main >/dev/null 2>&1
  git -C "$clone" push -u origin main >/dev/null 2>&1
  cd "$clone" || exit 1
}

@test "writes rc1 cycle tree with manifest and notes" {
  _init_git_with_origin
  mkdir -p packages/server
  printf '%s\n' '{"name":"@t/server","version":"1.2.3"}' >packages/server/package.json

  run env UTC_DATE_OVERRIDE=2099.12.31 \
    UTC_TIMESTAMP_OVERRIDE=2099-12-31T12:00:00Z \
    DEPLOYABLE_PACKAGES=server=packages/server \
    MANIFEST_TRAIN_TAG_PREFIX=release/ \
    node "$PROJECT_ROOT/src/scripts/writeReleaseCycle.mjs"
  assert_success
  assert_output --partial ".releases/2099.12.31.1/rc1/manifest.yml"
  assert [ -f ".releases/2099.12.31.1/cycle.yml" ]
  assert [ -f ".releases/2099.12.31.1/rc1/manifest.yml" ]
  assert [ -f ".releases/2099.12.31.1/rc1/notes.md" ]
  run grep -F "release: 2099.12.31.1" ".releases/2099.12.31.1/cycle.yml"
  assert_success
  run grep -F "rc: 1" ".releases/2099.12.31.1/rc1/manifest.yml"
  assert_success
  run grep -F "server: server-v1.2.3" ".releases/2099.12.31.1/rc1/manifest.yml"
  assert_success
}

@test "adds rc2 under open cycle on soak cut" {
  _init_git_with_origin
  mkdir -p packages/server .releases
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" .releases/
  printf '%s\n' '{"name":"@t/server","version":"1.2.4"}' >packages/server/package.json
  git add -A
  git commit -m "seed open cycle" >/dev/null 2>&1

  run env UTC_DATE_OVERRIDE=2099.12.31 \
    UTC_TIMESTAMP_OVERRIDE=2099-12-31T15:00:00Z \
    DEPLOYABLE_PACKAGES=server=packages/server \
    node "$PROJECT_ROOT/src/scripts/writeReleaseCycle.mjs"
  assert_success
  assert_output --partial "RC_INDEX=2"
  assert [ -f ".releases/2026.05.08.1/rc2/manifest.yml" ]
  run grep -F "rc: 2" ".releases/2026.05.08.1/rc2/manifest.yml"
  assert_success
}

@test "staged writer matches source module output" {
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-parity"
  _init_git_with_origin
  mkdir -p packages/server
  printf '%s\n' '{"name":"@t/server","version":"2.3.4"}' >packages/server/package.json

  WRITE_RELEASE_CYCLE_STAGE_DIR="$stage_dir" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh" >/dev/null

  run env UTC_DATE_OVERRIDE=2099.12.31 \
    UTC_TIMESTAMP_OVERRIDE=2099-12-31T12:00:00Z \
    DEPLOYABLE_PACKAGES=server=packages/server \
    RELEASES_DIR=.releases-source \
    node "$PROJECT_ROOT/src/scripts/writeReleaseCycle.mjs"
  assert_success
  source_manifest=$(cat ".releases-source/2099.12.31.1/rc1/manifest.yml")

  rm -rf ".releases-source"
  run env UTC_DATE_OVERRIDE=2099.12.31 \
    UTC_TIMESTAMP_OVERRIDE=2099-12-31T12:00:00Z \
    DEPLOYABLE_PACKAGES=server=packages/server \
    RELEASES_DIR=.releases-staged \
    node "${stage_dir}/writeReleaseCycle.mjs"
  assert_success
  staged_manifest=$(cat ".releases-staged/2099.12.31.1/rc1/manifest.yml")

  assert_equal "$source_manifest" "$staged_manifest"
}

@test "formats rc notes from staged CHANGELOG.md updates" {
  _init_git_with_origin
  mkdir -p packages/server
  printf '%s\n' '{"name":"@t/server","version":"1.2.3"}' >packages/server/package.json
  cat >packages/server/CHANGELOG.md <<'EOF'
# @t/server

## 1.2.3

### Patch Changes

- Features: add cycle notes formatting
EOF
  git add packages/server
  git commit -m "changelog" >/dev/null 2>&1

  run env UTC_DATE_OVERRIDE=2099.12.31 \
    UTC_TIMESTAMP_OVERRIDE=2099-12-31T12:00:00Z \
    DEPLOYABLE_PACKAGES=server=packages/server \
    RELEASE_NOTES_GROUPING=category \
    RC_NOTES_CHANGELOG_PATHS=packages/server/CHANGELOG.md \
    node "$PROJECT_ROOT/src/scripts/writeReleaseCycle.mjs"
  assert_success
  run grep -F "### Features" ".releases/2099.12.31.1/rc1/notes.md"
  assert_success
  run grep -F "add cycle notes formatting" ".releases/2099.12.31.1/rc1/notes.md"
  assert_success
}
