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
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/lint --flag chiubaka-lint"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @chiubaka/e2e-tests --flag chiubaka-e2e-tests"
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
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/pkg!!name --flag chiubaka-pkg-name"
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
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name $long_name --flag scope-abcdefghijklmnopqrstuvwxyz1234567890abc"
}

@test "adds hash suffix when sanitized flags collide" {
  colliding_pnpm_ls_json="[{\"name\":\"@a/b\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"a-b\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  run bash -lc "printf '%s' 'a-b' | sha256sum | cut -c1-8"
  assert_success
  hash_suffix="$output"

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @a/b --flag a-b"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name a-b --flag a-b-$hash_suffix"
}

@test "omits token and optional args when unset" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin"
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
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e"
}

@test "skips packages with missing coverage directories" {
  rm -d "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  # Entire tree exists under coverage root, but root must not trigger one --name monorepo-root --flag monorepo-root upload.
  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin-e2e because $COVERAGE_DIR/e2e/nx-plugin-e2e does not exist"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
}
