#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "writes manifest with predicted artifact tags" {
  cd "$BATS_TEST_TMPDIR" || exit 1
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
