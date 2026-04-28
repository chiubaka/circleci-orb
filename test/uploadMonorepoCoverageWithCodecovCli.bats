setup() {
  load "helpers/setup"
  _setup

  COVERAGE_DIR="$TEST_DIR"/fixtures/coverage
  mkdir -p "$COVERAGE_DIR"/packages/nx-plugin
  mkdir -p "$COVERAGE_DIR"/e2e/nx-plugin-e2e

  pnpm_mock=$(mock_create)
  pnpm_ls_json="[{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"nx-plugin-e2e\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$pnpm_ls_json"
}

teardown() {
  rm -rf "$COVERAGE_DIR"
}

@test "uploads one coverage report per monorepo package with package flag" {
  codecov_mock=$(mock_create)

  # Clear token so assertions match; CI may inject CODECOV_TOKEN.
  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_FAIL_ON_ERROR=true \
  CODECOV_VERBOSE=true \
  CODECOV_DISABLE_SEARCH=true \
  CODECOV_FILES="coverage.xml,coverage-final.json" \
  CODECOV_FLAGS="unit,monorepo" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error --verbose --disable-search --file coverage.xml --file coverage-final.json --flag unit --flag monorepo"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error --verbose --disable-search --file coverage.xml --file coverage-final.json --flag unit --flag monorepo"
}

@test "sanitizes scoped package names into Codecov-safe flags" {
  scoped_pnpm_ls_json="[{\"name\":\"@chiubaka/lint\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@chiubaka/e2e-tests\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$scoped_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/lint --flag lint --fail-on-error --verbose"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @chiubaka/e2e-tests --flag e2e-tests --fail-on-error --verbose"
}

@test "normalizes disallowed characters in package-derived flags" {
  weird_pnpm_ls_json="[{\"name\":\"@chiubaka/pkg!!name\",\"path\":\"$TEST_DIR/packages/nx-plugin\"}]"
  mock_set_output "${pnpm_mock}" "$weird_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/pkg!!name --flag pkg-name --fail-on-error --verbose"
}

@test "truncates long package-derived flags to Codecov max length" {
  long_name="@scope/abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"
  long_pnpm_ls_json="[{\"name\":\"$long_name\",\"path\":\"$TEST_DIR/packages/nx-plugin\"}]"
  mock_set_output "${pnpm_mock}" "$long_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name $long_name --flag abcdefghijklmnopqrstuvwxyz1234567890abcdefghi --fail-on-error --verbose"
}

@test "adds scope back when unscoped flag collides" {
  colliding_pnpm_ls_json="[{\"name\":\"@a/pkg\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@b/pkg\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @a/pkg --flag pkg --fail-on-error --verbose"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @b/pkg --flag b-pkg --fail-on-error --verbose"
}

@test "resolves collisions introduced by 45-char truncation via scope fallback" {
  long_leaf="abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"
  colliding_pnpm_ls_json="[{\"name\":\"@alpha/$long_leaf\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@beta/$long_leaf\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @alpha/$long_leaf --flag abcdefghijklmnopqrstuvwxyz1234567890abcdefghi --fail-on-error --verbose"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @beta/$long_leaf --flag beta-abcdefghijklmnopqrstuvwxyz1234567890abcd --fail-on-error --verbose"
}

@test "fails loudly when unscoped and scoped candidates both collide" {
  colliding_pnpm_ls_json="[{\"name\":\"@a/pkg\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"b-pkg\",\"path\":\"$TEST_DIR/extra/b-pkg\"},{\"name\":\"@b/pkg\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  mkdir -p "$COVERAGE_DIR"/extra/b-pkg
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: unable to derive unique Codecov flag for package @b/pkg. Unscoped candidate 'pkg' collides with @a/pkg, and scoped candidate 'b-pkg' collides with b-pkg."
}

@test "omits token and optional args when unset" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_FAIL_ON_ERROR=false \
  CODECOV_VERBOSE=false \
  CODECOV_REQUIRE_UPLOADS=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin"
}

@test "defaults fail-on-error and verbose to true" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error --verbose"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error --verbose"
}

@test "skips workspace root package; does not upload full coverage tree under root name" {
  pnpm_ls_with_root="[{\"name\":\"monorepo-root\",\"path\":\"$TEST_DIR\"},{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"nx-plugin-e2e\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$pnpm_ls_with_root"
  # Entire tree exists under coverage root, but root must not trigger one -F monorepo-root upload.
  mkdir -p "$COVERAGE_DIR"
  touch "$COVERAGE_DIR"/.placeholder

  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for workspace root package monorepo-root; per-package subdirectories only"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error --verbose"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error --verbose"
}

@test "skips packages with missing coverage directories" {
  rm -d "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  # Entire tree exists under coverage root, but root must not trigger one --name monorepo-root --flag monorepo-root upload.
  CODECOV_TOKEN='' \
  CODECOV_FAIL_ON_ERROR=false \
  CODECOV_VERBOSE=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin-e2e because $COVERAGE_DIR/e2e/nx-plugin-e2e does not exist"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
}

@test "fails when no package coverage reports are uploaded by default" {
  rm -rf "$COVERAGE_DIR"/packages/nx-plugin "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: no coverage reports were uploaded."
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 0
}

@test "allows empty uploads when CODECOV_REQUIRE_UPLOADS is false" {
  rm -rf "$COVERAGE_DIR"/packages/nx-plugin "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_REQUIRE_UPLOADS=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 0
}
