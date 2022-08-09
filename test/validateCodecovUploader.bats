setup_file() {
  load "helpers/setup"
  _setup

  VERSION=latest BASH_ENV=$TEST_DIR/.bash_env run downloadCodeCovUploader.sh
}

setup() {
  load "helpers/setup"
  _setup

  BASH_ENV=$TEST_DIR/.bash_env
}

teardown_file() {
  rm $PROJECT_ROOT/codecov
  rm $TEST_DIR/.bash_env

  rm $PROJECT_ROOT/codecov.SHA256SUM
  rm $PROJECT_ROOT/codecov.SHA256SUM.sig
}

@test "validates the SHA hash of the downloaded codecov uploader" {
  VERSION=latest BASH_ENV=$TEST_DIR/.bash_env run validateCodecovUploader.sh
  assert_success
}
