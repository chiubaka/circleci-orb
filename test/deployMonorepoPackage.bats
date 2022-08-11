setup() {
  load "helpers/setup"
  _setup
}

@test "calls yarn deploy:ci for the correct package" {
  mock=$(mock_create)

  PARSE_MONOREPO_DEPLOY_TAG_SCRIPT="$PROJECT_ROOT/src/scripts/parseMonorepoDeployTag.sh" \
  YARN_BINARY="${mock}" \
  CIRCLE_TAG="nx-plugin-v0.0.1" \
  run deployMonorepoPackage.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "deploy:ci nx-plugin"
}

@test "respects the DRY_RUN environment variable" {
  mock=$(mock_create)

  PARSE_MONOREPO_DEPLOY_TAG_SCRIPT="$PROJECT_ROOT/src/scripts/parseMonorepoDeployTag.sh" \
  YARN_BINARY="${mock}" \
  CIRCLE_TAG="nx-plugin-v0.0.1" \
  DRY_RUN=true \
  run deployMonorepoPackage.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "deploy:ci nx-plugin --dry-run"
}
