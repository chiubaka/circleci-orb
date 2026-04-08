setup() {
  load "helpers/setup"
  _setup
}

@test "runs pnpm exec changeset status when VERIFY_SCRIPT is empty" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT='' \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "exec changeset status"
}

@test "runs pnpm run when verify-script is set" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  VERIFY_SCRIPT=changeset:check \
  run runVerifyChangesets.sh

  assert_success
  assert_equal "$(mock_get_call_args "${mock}")" "run changeset:check"
}
