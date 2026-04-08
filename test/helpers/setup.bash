#! /usr/bin/env bash

_setup() {
  TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PROJECT_ROOT="$TEST_DIR"
  while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/package.json" && -d "$PROJECT_ROOT/src" ]]; then
      break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
  done
  if [[ ! -f "$PROJECT_ROOT/package.json" ]]; then
    echo "_setup: could not locate repo root (package.json + src/) from ${TEST_DIR}" >&2
    exit 1
  fi
  export PROJECT_ROOT

  PATH="$PROJECT_ROOT/src/scripts:$PATH"

  load "$PROJECT_ROOT/node_modules/bats-assert/load"
  load "$PROJECT_ROOT/node_modules/bats-support/load"

  load "$PROJECT_ROOT/node_modules/bats-file/load"
  load "$PROJECT_ROOT/node_modules/bats-mock/load"
}
