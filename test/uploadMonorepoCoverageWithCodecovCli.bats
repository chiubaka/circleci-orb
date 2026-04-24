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

@test "skips packages with missing coverage directories" {
  rm -d "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

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
