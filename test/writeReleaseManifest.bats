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

@test "writes manifest with predicted artifact tags" {
  _init_git_with_origin
  mkdir -p packages/server apps/web
  printf '%s\n' '{"name":"@t/server","version":"1.2.3"}' >packages/server/package.json
  printf '%s\n' '{"name":"@t/web","version":"4.5.6"}' >apps/web/package.json

  run env UTC_DATE_OVERRIDE=2099.12.31 \
    DEPLOYABLE_PACKAGES=server=packages/server,web=apps/web \
    MANIFEST_TRAIN_TAG_PREFIX=release/ \
    node "$PROJECT_ROOT/src/scripts/writeReleaseManifest.mjs"
  assert_success
  assert_output --partial ".releases/2099.12.31.1.yml"
  assert [ -f ".releases/2099.12.31.1.yml" ]
  run grep -F "release: 2099.12.31.1" ".releases/2099.12.31.1.yml"
  assert_success
  run grep -F "server: server-v1.2.3" ".releases/2099.12.31.1.yml"
  assert_success
  run grep -F "web: web-v4.5.6" ".releases/2099.12.31.1.yml"
  assert_success
}
