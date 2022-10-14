setup() {
  load "helpers/setup"
  _setup
}

@test "invokes docker with the correct arguments" {
  mock=$(mock_create)

  mock_set_output "${mock}" "project_default" 1

  DOCKER_BINARY="${mock}" \
  CONTAINER_NAME="genesis_registry_1" \
  URL="http://localhost:4873/healthcheck" \
  RETRY_INTERVAL="2s" \
  TIMEOUT="20s" \
  run waitForDockerService.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}" 1)" "container run --network container:genesis_registry_1 docker.io/jwilder/dockerize -wait http://localhost:4873/healthcheck -wait-retry-interval 2s -timeout 20s"
}
