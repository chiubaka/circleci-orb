setup() {
  load "helpers/setup"
  _setup
}

@test "default runs pnpm exec changeset publish" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  run runPublish.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "exec changeset publish"
}

@test "publish-script runs pnpm run with script name" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  PUBLISH_SCRIPT=ci:publish \
  run runPublish.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 1
  assert_equal "$(mock_get_call_args "${mock}")" "run ci:publish"
}

@test "dry-run default runs publish --help then publish --dry-run" {
  mock=$(mock_create)
  mock_set_output "${mock}" $'Usage: publish\n  --dry-run    dry run\n' 1
  mock_set_output "${mock}" "" 2

  PNPM_BINARY="${mock}" \
  DRY_RUN=true \
  run runPublish.sh

  assert_success
  assert_equal "$(mock_get_call_num "${mock}")" 2
  assert_equal "$(mock_get_call_args "${mock}" 1)" "exec changeset publish --help"
  assert_equal "$(mock_get_call_args "${mock}" 2)" "exec changeset publish --dry-run"
}

@test "dry-run with publish-script appends -- --dry-run" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  PUBLISH_SCRIPT=ci:publish \
  DRY_RUN=true \
  run runPublish.sh

  assert_success
  assert_equal "$(mock_get_call_args "${mock}")" "run ci:publish -- --dry-run"
}

@test "normalizes DRY_RUN True for publish-script mode" {
  mock=$(mock_create)

  PNPM_BINARY="${mock}" \
  PUBLISH_SCRIPT=release \
  DRY_RUN=True \
  run runPublish.sh

  assert_success
  assert_equal "$(mock_get_call_args "${mock}")" "run release -- --dry-run"
}

@test "dry-run fails when help omits --dry-run" {
  mock=$(mock_create)
  mock_set_output "${mock}" $'Usage: publish\n  --otp <code>\n' 1

  PNPM_BINARY="${mock}" \
  DRY_RUN=true \
  run runPublish.sh

  assert_failure
  assert_equal "$(mock_get_call_num "${mock}")" 1
}
