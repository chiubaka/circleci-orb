setup() {
  load "helpers/setup"
  _setup
}

@test "invokes docker with the correct arguments" {
  mock=$(mock_create)

  DOCKERIZE_BINARY="${mock}" \
  URL="http://localhost:4873/healthcheck" \
  RETRY_INTERVAL="2s" \
  TIMEOUT="20s" \
  run waitForDockerService.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "-wait http://localhost:4873/healthcheck -wait-retry-interval 2s -timeout 20s"
}
