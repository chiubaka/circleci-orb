setup() {
  load "helpers/setup"
  _setup

  COVERAGE_DIR="$TEST_DIR"/fixtures/coverage

  # Workspace root package: path equals MONOREPO_ROOT (see uploadMonorepoCoverageResults.sh).
  if [[ "${BATS_TEST_DESCRIPTION:-}" == *"workspace root package"* ]]; then
    mkdir -p "$COVERAGE_DIR"
    mkdir -p "$COVERAGE_DIR"/packages/nx-plugin
    pnpm_mock=$(mock_create)
    pnpm_ls_json="[{\"name\":\"root-workspace\",\"path\":\"$TEST_DIR\"},{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"}]"
    mock_set_output "${pnpm_mock}" "$pnpm_ls_json"
  else
    mkdir -p "$COVERAGE_DIR"/packages/nx-plugin
    mkdir -p "$COVERAGE_DIR"/e2e/nx-plugin-e2e
    pnpm_mock=$(mock_create)
    pnpm_ls_json="[{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"nx-plugin-e2e\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
    mock_set_output "${pnpm_mock}" "$pnpm_ls_json"
  fi
}

teardown() {
  rm -rf "$COVERAGE_DIR"
}

@test "uploads coverage for workspace root package to COVERAGE_DIR (no path join bug)" {
  codecov_mock=$(mock_create)

  BASH_ENV=$TEST_DIR/fixtures/.bash_env \
  CODECOV_BINARY="${codecov_mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR -F root-workspace"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin"
}

@test "uploads one coverage report to Codecov per monorepo package" {
  codecov_mock=$(mock_create)

  BASH_ENV=$TEST_DIR/fixtures/.bash_env \
  CODECOV_BINARY="${codecov_mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-t test-token -n 32 --dir $COVERAGE_DIR/e2e/nx-plugin-e2e -F nx-plugin-e2e --extra extra-arg"
}

@test "skips upload gracefully if a project coverage directory does not exist" {
  rm -d "$COVERAGE_DIR"/e2e/nx-plugin-e2e

  codecov_mock=$(mock_create)

  BASH_ENV=$TEST_DIR/fixtures/.bash_env \
  CODECOV_BINARY="${codecov_mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_output "Skipping coverage upload for nx-plugin-e2e because $COVERAGE_DIR/e2e/nx-plugin-e2e does not exist"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
}

@test "exits with an error if Codecov upload fails" {
  codecov_mock=$(mock_create)
  mock_set_status "${codecov_mock}" 1 2

  BASH_ENV=$TEST_DIR/fixtures/.bash_env \
  CODECOV_BINARY="${codecov_mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageResults.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-t test-token -n 32 --dir $COVERAGE_DIR/e2e/nx-plugin-e2e -F nx-plugin-e2e --extra extra-arg"
}
