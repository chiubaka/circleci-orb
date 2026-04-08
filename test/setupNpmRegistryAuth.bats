setup() {
  load "helpers/setup"
  _setup

  NPMRC_PATH="$TEST_DIR"/fixtures/.npmrc
}

teardown() {
  rm -f "$NPMRC_PATH"
}

@test "npmjs writes token line only when always-auth is unset and backend implied" {
  NPMRC_PATH=$NPMRC_PATH NPM_TOKEN=foobar run setupNpmRegistryAuth.sh

  assert_success
  assert_file_exists "$NPMRC_PATH"
  assert_equal "//registry.npmjs.org/:_authToken=foobar" "$(cat "$NPMRC_PATH")"
}

@test "npmjs with ALWAYS_AUTH=true adds always-auth line" {
  NPMRC_PATH=$NPMRC_PATH NPM_TOKEN=foo ALWAYS_AUTH=true run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 0 '//registry.npmjs.org/:_authToken=foo'
  assert_line --index 1 '//registry.npmjs.org/:always-auth=true'
}

@test "github-packages writes scope, token, and always-auth by default" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages GITHUB_TOKEN=ghp_x run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 0 '@chiubaka:registry=https://npm.pkg.github.com'
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_x'
  assert_line --index 2 '//npm.pkg.github.com/:always-auth=true'
}

@test "github-packages respects custom owner scope" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages NPM_OWNER=acme GITHUB_TOKEN=ghp_x ALWAYS_AUTH=false run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 0 '@acme:registry=https://npm.pkg.github.com'
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_x'
  refute_line --partial 'always-auth'
}

@test "fails when npmjs and NPM_TOKEN missing" {
  NPMRC_PATH=$NPMRC_PATH run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'NPM_TOKEN must be set'
}

@test "fails when github-packages and GITHUB_TOKEN missing" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'GITHUB_TOKEN must be set'
}

@test "fails on unknown registry backend" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=other NPM_TOKEN=x run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'unknown REGISTRY_BACKEND'
}
