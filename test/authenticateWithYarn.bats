setup() {
  load "helpers/setup"
  _setup

  NPMRC_PATH="$TEST_DIR"/examples/.npmrc
}

teardown() {
  rm "$NPMRC_PATH"
}

@test "writes to .npmrc" {
  NPMRC_PATH=$NPMRC_PATH NPM_TOKEN=foobar run authenticateWithYarn.sh

  assert_success
  assert_file_exists "$NPMRC_PATH"
  assert_equal "//registry.yarnpkg.com/:_authToken=foobar" "$(cat "$NPMRC_PATH")"
}
