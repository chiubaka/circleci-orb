setup() {
  load "helpers/setup"
  _setup
}

@test "uploads one coverage report to Codecov per monorepo package" {
  mock=$(mock_create)
  BASH_ENV=$TEST_DIR/examples/.bash_env \
  CODECOV_BINARY="${mock}" \
  CODECOV_TOKEN=test-token \
  CIRCLE_BUILD_NUM=32 \
  WORKSPACE_JSON="$TEST_DIR"/examples/workspace.json \
  COVERAGE_DIR=coverage \
  XTRA_ARGS="--extra extra-arg" \
  PARSE_NX_PROJECTS_SCRIPT="$PROJECT_ROOT"/src/scripts/parseNxProjects.sh \
  run uploadMonorepoCoverageResults.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 2
  assert_equal "$(mock_get_call_args "${mock}" 1)" "-t test-token -n 32 -f coverage/packages/nx-plugin -F nx-plugin --extra extra-arg"
  assert_equal "$(mock_get_call_args "${mock}" 2)" "-t test-token -n 32 -f coverage/e2e/nx-plugin-e2e -F nx-plugin-e2e --extra extra-arg"
}
