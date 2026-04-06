setup() {
  load "helpers/setup"
  _setup

  MONOREPO_ROOT="$TEST_DIR/fixtures/generateMainConfig"

  pnpm_mock=$(mock_create)
  turbo_mock=$(mock_create)

  # Default mock outputs: no tasks / no packages
  mock_set_output "${turbo_mock}" '{"tasks":[]}'
  mock_set_output "${pnpm_mock}" '[]'
}

teardown() {
  rm -f "$MONOREPO_ROOT/.circleci/main.yml"
  rm -f "$MONOREPO_ROOT/.circleci/params.json"
}

# ---------------------------------------------------------------------------
# JS project (no React Native detected)
# ---------------------------------------------------------------------------

@test "generates main.yml from JS template when no React Native projects are detected" {
  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_file_exists "$MONOREPO_ROOT/.circleci/main.yml"
  assert_file_contains "$MONOREPO_ROOT/.circleci/main.yml" "JS CI template"
}

@test "writes an empty params.json when no React Native projects are detected" {
  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_file_exists "$MONOREPO_ROOT/.circleci/params.json"
  assert_equal "{}" "$(cat "$MONOREPO_ROOT/.circleci/params.json")"
}

@test "logs that the JS template is being used when no React Native projects are detected" {
  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_output --partial "No React Native projects found. Using JS CI template."
}

# ---------------------------------------------------------------------------
# React Native project (iOS only, primary branch)
# ---------------------------------------------------------------------------

# Configure mocks for a monorepo with one iOS-only React Native app.
# The ios-app package fixture lives at test/fixtures/generateMainConfig/packages/ios-app/
# with a committed .xcode-version and fastlane/Fastlane.env.
#
# turbo call order (primary branch → no affected filter, no tag):
#   1: run:ios  (all)          → ios-app found
#   2: run:android (all)       → nothing
#   3: build:ios               → ios-app
#   4: build:android           → nothing
#   5: test:ios                → ios-app
#   6: test:android            → nothing
#   7: e2e:ios                 → ios-app
#   8: e2e:android             → nothing
#   9: run:ios  (affected)     → ios-app
#  10: run:android (affected)  → nothing
setup_ios_fixture() {
  local pkg_dir="$MONOREPO_ROOT/packages/ios-app"
  local ios_task_json="{\"tasks\":[{\"taskId\":\"ios-app#run:ios\",\"package\":\"ios-app\",\"task\":\"run:ios\"}]}"

  mock_set_output "${turbo_mock}" "$ios_task_json" 1
  mock_set_output "${turbo_mock}" "$ios_task_json" 3
  mock_set_output "${turbo_mock}" "$ios_task_json" 5
  mock_set_output "${turbo_mock}" "$ios_task_json" 7
  mock_set_output "${turbo_mock}" "$ios_task_json" 9

  mock_set_output "${pnpm_mock}" \
    "[{\"name\":\"ios-app\",\"path\":\"$pkg_dir\"}]"
}

@test "detects React Native when iOS projects are found" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_output --partial "Detected React Native projects. Using React Native CI template."
}

@test "generates main.yml from React Native template when iOS projects are detected" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_file_exists "$MONOREPO_ROOT/.circleci/main.yml"
  assert_file_contains "$MONOREPO_ROOT/.circleci/main.yml" "React Native CI template"
}

@test "writes params.json with correct platform flags when iOS only project is detected" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_file_exists "$MONOREPO_ROOT/.circleci/params.json"
  assert_equal "true" "$(jq -r '.["build-ios"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "false" "$(jq -r '.["build-android"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "true" "$(jq -r '.["test-ios"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "false" "$(jq -r '.["test-android"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "true" "$(jq -r '.["e2e-ios"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "false" "$(jq -r '.["e2e-android"]' "$MONOREPO_ROOT/.circleci/params.json")"
}

@test "includes the Xcode version from .xcode-version in params.json" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_equal "15.2" "$(jq -r '.["xcode-version"]' "$MONOREPO_ROOT/.circleci/params.json")"
}

@test "includes the iOS simulator config from Fastlane.env in params.json" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_equal "iPhone 15" "$(jq -r '.["ios-simulator-device"]' "$MONOREPO_ROOT/.circleci/params.json")"
  assert_equal "17.0" "$(jq -r '.["ios-simulator-version"]' "$MONOREPO_ROOT/.circleci/params.json")"
}

@test "includes the setup-ios-app step for the affected iOS project" {
  setup_ios_fixture

  CIRCLE_WORKING_DIRECTORY="$MONOREPO_ROOT" \
  PRIMARY_BRANCH=main \
  CIRCLE_BRANCH=main \
  CIRCLE_TAG='' \
  TURBO_BINARY="${turbo_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run generateMainConfig.sh

  assert_success
  assert_file_contains "$MONOREPO_ROOT/.circleci/main.yml" "chiubaka/setup-ios-app"
  assert_file_contains "$MONOREPO_ROOT/.circleci/main.yml" "packages/ios-app"
}
