setup() {
  load "helpers/setup"
  _setup

  COVERAGE_DIR="$TEST_DIR"/examples/coverage
  mkdir -p "$COVERAGE_DIR"/packages/nx-plugin
  mkdir -p "$COVERAGE_DIR"/e2e/nx-plugin-e2e
}

teardown() {
  rm -rf "$COVERAGE_DIR"
}

@test "uploads one coverage report to Codecov per monorepo package" {
  mock=$(mock_create)
  BASH_ENV=$TEST_DIR/examples/.bash_env \
  CODECOV_BINARY="${mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  WORKSPACE_JSON="$TEST_DIR"/examples/workspace.json \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PARSE_NX_PROJECTS_SCRIPT="$PROJECT_ROOT"/src/scripts/parseNxProjects.sh \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 2
  assert_equal "$(mock_get_call_args "${mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
  assert_equal "$(mock_get_call_args "${mock}" 2)" "-t test-token -n 32 --dir $COVERAGE_DIR/e2e/nx-plugin-e2e -F nx-plugin-e2e --extra extra-arg"
}

@test "skips upload gracefully if a project coverage directory does not exist" {
  rm -d "$COVERAGE_DIR"/e2e/nx-plugin-e2e

  mock=$(mock_create)
  BASH_ENV=$TEST_DIR/examples/.bash_env \
  CODECOV_BINARY="${mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  WORKSPACE_JSON="$TEST_DIR"/examples/workspace.json \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PARSE_NX_PROJECTS_SCRIPT="$PROJECT_ROOT"/src/scripts/parseNxProjects.sh \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_output "Skipping coverage upload for nx-plugin-e2e because $COVERAGE_DIR/e2e/nx-plugin-e2e does not exist"
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
}

@test "exits with an error if Codecov upload fails" {
  mock=$(mock_create)
  mock_set_status "${mock}" 1 2
  BASH_ENV=$TEST_DIR/examples/.bash_env \
  CODECOV_BINARY="${mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  WORKSPACE_JSON="$TEST_DIR"/examples/workspace.json \
  COVERAGE_DIR=$COVERAGE_DIR \
  XTRA_ARGS="--extra extra-arg" \
  PARSE_NX_PROJECTS_SCRIPT="$PROJECT_ROOT"/src/scripts/parseNxProjects.sh \
  run uploadMonorepoCoverageResults.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 2
  assert_equal "$(mock_get_call_args "${mock}" 1)" "-t test-token -n 32 --dir $COVERAGE_DIR/packages/nx-plugin -F nx-plugin --extra extra-arg"
  assert_equal "$(mock_get_call_args "${mock}" 2)" "-t test-token -n 32 --dir $COVERAGE_DIR/e2e/nx-plugin-e2e -F nx-plugin-e2e --extra extra-arg"
}
