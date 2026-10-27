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
  run env -u GITHUB_PACKAGES_READ_TOKEN -u GITHUB_PACKAGES_TOKEN \
    NPMRC_PATH="$NPMRC_PATH" REGISTRY_BACKEND=github-packages GITHUB_TOKEN=ghp_x \
    setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 0 '@chiubaka:registry=https://npm.pkg.github.com'
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_x'
  assert_line --index 2 '//npm.pkg.github.com/:always-auth=true'
}

@test "github-packages respects custom owner scope" {
  run env -u GITHUB_PACKAGES_READ_TOKEN -u GITHUB_PACKAGES_TOKEN \
    NPMRC_PATH="$NPMRC_PATH" REGISTRY_BACKEND=github-packages NPM_OWNER=acme \
    GITHUB_TOKEN=ghp_x ALWAYS_AUTH=false setupNpmRegistryAuth.sh

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

@test "fails when github-packages and packages-read tokens missing" {
  run env -u GITHUB_TOKEN -u GITHUB_PACKAGES_TOKEN -u GITHUB_PACKAGES_READ_TOKEN \
    NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'GITHUB_PACKAGES_READ_TOKEN must be set'
}

@test "github-packages prefers GITHUB_PACKAGES_READ_TOKEN over aliases" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages \
    GITHUB_TOKEN=ghs_minted GITHUB_PACKAGES_TOKEN=ghp_deprecated \
    GITHUB_PACKAGES_READ_TOKEN=ghp_read \
    run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_read'
}

@test "github-packages read access prefers GITHUB_PACKAGES_READ_TOKEN over write-capable fallbacks" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages REGISTRY_ACCESS=read \
    GITHUB_TOKEN=ghp_write GITHUB_PACKAGES_TOKEN=ghp_deprecated \
    GITHUB_PACKAGES_READ_TOKEN=ghp_read \
    run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_read'
}

@test "github-packages publish access prefers write-capable token over GITHUB_PACKAGES_READ_TOKEN" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages REGISTRY_ACCESS=publish \
    GITHUB_TOKEN=ghp_write GITHUB_PACKAGES_TOKEN=ghp_publish \
    GITHUB_PACKAGES_READ_TOKEN=ghp_read \
    run setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_publish'
}

@test "github-packages publish access falls back to GITHUB_TOKEN before GITHUB_PACKAGES_READ_TOKEN" {
  run env -u GITHUB_PACKAGES_TOKEN \
    NPMRC_PATH="$NPMRC_PATH" REGISTRY_BACKEND=github-packages REGISTRY_ACCESS=publish \
    GITHUB_TOKEN=ghp_write GITHUB_PACKAGES_READ_TOKEN=ghp_read \
    setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_write'
}

@test "github-packages publish access can still use GITHUB_PACKAGES_READ_TOKEN alone" {
  run env -u GITHUB_TOKEN -u GITHUB_PACKAGES_TOKEN \
    NPMRC_PATH="$NPMRC_PATH" REGISTRY_BACKEND=github-packages REGISTRY_ACCESS=publish \
    GITHUB_PACKAGES_READ_TOKEN=ghp_read \
    setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_read'
}

@test "github-packages prefers deprecated GITHUB_PACKAGES_TOKEN over GITHUB_TOKEN" {
  run env -u GITHUB_PACKAGES_READ_TOKEN \
    NPMRC_PATH="$NPMRC_PATH" REGISTRY_BACKEND=github-packages \
    GITHUB_TOKEN=ghs_minted GITHUB_PACKAGES_TOKEN=ghp_packages \
    setupNpmRegistryAuth.sh

  assert_success
  run cat "$NPMRC_PATH"
  assert_line --index 1 '//npm.pkg.github.com/:_authToken=ghp_packages'
}

@test "fails when github-packages GITHUB_TOKEN is an installation token without packages-read env" {
  run env -u GITHUB_PACKAGES_TOKEN -u GITHUB_PACKAGES_READ_TOKEN \
    NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=github-packages \
    GITHUB_TOKEN=ghs_minted_only setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'installation token'
  assert_output --partial 'GITHUB_PACKAGES_READ_TOKEN'
}

@test "fails on unknown registry backend" {
  NPMRC_PATH=$NPMRC_PATH REGISTRY_BACKEND=other NPM_TOKEN=x run setupNpmRegistryAuth.sh

  assert_failure
  assert_output --partial 'unknown REGISTRY_BACKEND'
}
