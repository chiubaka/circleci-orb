#!/usr/bin/env bats

setup_file() {
  load "helpers/setup"
  _setup
}

setup() {
  load "helpers/setup"
  _setup
  BASH_ENV="$TEST_DIR/.bash_env"
}

teardown_file() {
  rm -f "$PROJECT_ROOT/codecov" "$PROJECT_ROOT/codecov.exe"
  rm -f "$TEST_DIR/.bash_env"
  rm -f "$PROJECT_ROOT/codecov.SHA256SUM" "$PROJECT_ROOT/codecov.SHA256SUM.sig"
}

@test "download-only prepares executable and BASH_ENV exports" {
  cd "$PROJECT_ROOT" || exit 1
  VERSION=latest RUN_VALIDATE=false BASH_ENV="$BASH_ENV" run setupCodecovLegacyUploader.sh
  assert_success
  assert_file_exists "$PROJECT_ROOT/codecov"
  assert_file_executable "$PROJECT_ROOT/codecov"

  # shellcheck source=/dev/null
  source "$BASH_ENV"

  assert [ -v OS ]
  assert_equal "$CODECOV_FILENAME" "codecov"
  assert_equal "$(realpath "$CODECOV_BINARY")" "$(realpath "$PROJECT_ROOT/codecov")"
}

@test "with validation verifies checksums for the downloaded uploader" {
  cd "$PROJECT_ROOT" || exit 1
  VERSION=latest RUN_VALIDATE=true BASH_ENV="$BASH_ENV" run setupCodecovLegacyUploader.sh
  assert_success
}
