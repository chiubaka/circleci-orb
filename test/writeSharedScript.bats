setup() {
  load "helpers/setup"
  _setup

  SCRIPT_DIR="$TEST_DIR"/@chiubaka/circleci-orb/scripts
  SCRIPT_PATH="$TEST_DIR"/@chiubaka/circleci-orb/scripts/test.sh

  SCRIPT="echo foobar" SCRIPT_DIR=$SCRIPT_DIR SCRIPT_NAME=test.sh run writeSharedScript.sh
}

teardown() {
  rm "$SCRIPT_PATH"
  rm -r "$SCRIPT_DIR"
}

@test "writes the shared script to disc at the specified location" {
  assert_file_exists "$SCRIPT_PATH"
}

@test "makes the shared script executable" {
  assert_file_executable "$SCRIPT_PATH"
}

@test "writes the correct content for the script" {
  assert_equal "echo foobar" "$(cat "$SCRIPT_PATH")"
}
