setup_file() {
  load "helpers/setup"
  _setup

  VERSION=latest BASH_ENV="$TEST_DIR"/.bash_env run downloadCodeCovUploader.sh
}

setup() {
  load "helpers/setup"
  _setup

  BASH_ENV="$TEST_DIR"/.bash_env
}

teardown_file() {
  rm "$PROJECT_ROOT"/codecov
  rm "$TEST_DIR"/.bash_env
}

@test "downloads an executable codecov binary" {
  assert_file_exists "$PROJECT_ROOT"/codecov
  assert_file_executable "$PROJECT_ROOT"/codecov
}

@test "writes the OS environment variable to BASH_ENV" {
  # shellcheck source=/dev/null
  source "$BASH_ENV"

  assert [ -v OS ]
}

@test "writes the CODECOV_FILENAME environment variable to BASH_ENV" {
  # shellcheck source=/dev/null
  source "$BASH_ENV"

  assert_equal "$CODECOV_FILENAME" "codecov"
}

@test "writes the CODECOV_BINARY environment variable to BASH_ENV" {
  # shellcheck source=/dev/null
  source "$BASH_ENV"

  assert_equal "$(realpath "$CODECOV_BINARY")" "$(realpath "$PROJECT_ROOT"/codecov)"
}
