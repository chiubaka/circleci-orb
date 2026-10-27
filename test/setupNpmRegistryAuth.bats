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

@test "fails when npmjs and NPM_TOKEN missing and registry-access is publish" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_ACCESS=publish run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'NPM_TOKEN must be set'
}

@test "npmjs read without NPM_TOKEN skips auth" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_ACCESS=read run setupNpmRegistryAuth.sh

  assert_success
  assert_output --partial 'skipping npmjs auth'
  [[ ! -e "$NPMRC_PATH" ]]
}

@test "fails when github-packages and GITHUB_TOKEN missing" {
  run env -u GITHUB_TOKEN -u GITHUB_PACKAGES_TOKEN NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'GITHUB_TOKEN (or GITHUB_PACKAGES_TOKEN) must be set'
}

@test "github-packages prefers GITHUB_PACKAGES_TOKEN over GITHUB_TOKEN" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages \
    GITHUB_TOKEN=ghs_minted GITHUB_PACKAGES_TOKEN=ghp_packages \
    run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_packages'
}

@test "fails when github-packages GITHUB_TOKEN is an installation token without GITHUB_PACKAGES_TOKEN" {
  run env -u GITHUB_PACKAGES_TOKEN NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages \
    GITHUB_TOKEN=ghs_minted_only setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'installation token'
  assert_output --partial 'packages-read'
}

@test "fails on unknown registry backend" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=other NPM_TOKEN=x run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'unknown REGISTRY_BACKEND'
}
