#! /usr/bin/env bash

_setup() {
  TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PROJECT_ROOT="$TEST_DIR/.."

  PATH="$PROJECT_ROOT/src/scripts:$PATH"

  load "$PROJECT_ROOT/node_modules/bats-assert/load"
  load "$PROJECT_ROOT/node_modules/bats-support/load"

  load "$PROJECT_ROOT/node_modules/bats-file/load"
  load "$PROJECT_ROOT/node_modules/bats-mock/load"
}
