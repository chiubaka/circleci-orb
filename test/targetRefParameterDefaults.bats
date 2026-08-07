#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

# CircleCI fails config compile when an orb parameter default expands
# << pipeline.git.revision >> in pipelines that lack that value (API/schedule/etc.).
# Defaults must be empty so scripts can fall back to CIRCLE_SHA1 / HEAD at runtime.

@test "parameter defaults do not expand pipeline.git.revision" {
  run grep -R --include='*.yml' -n 'default:.*"\?<<[[:space:]]*pipeline\.git\.revision' \
    "$PROJECT_ROOT/src/commands" "$PROJECT_ROOT/src/jobs"
  assert_failure
  assert_equal "$output" ""
}

_assert_target_ref_empty_default() {
  local file=$1
  local block
  block=$(sed -n '/^parameters:/,/^[^[:space:]#]/p' "$file" | grep -A8 -E '^[[:space:]]*target-ref:')
  [[ -n "$block" ]] || {
    echo "no target-ref parameter in ${file}" >&2
    return 1
  }
  [[ "$block" == *'default: ""'* ]] || {
    echo "expected empty string default in target-ref block of ${file}:" >&2
    echo "$block" >&2
    return 1
  }
  [[ "$block" != *'<< pipeline.git.revision >>'* ]] || {
    echo "target-ref default still references pipeline.git.revision in ${file}:" >&2
    echo "$block" >&2
    return 1
  }
}

@test "promote-prod-release job target-ref defaults to empty string" {
  _assert_target_ref_empty_default "$PROJECT_ROOT/src/jobs/promote-prod-release.yml"
}

@test "promote-prod-release command target-ref defaults to empty string" {
  _assert_target_ref_empty_default "$PROJECT_ROOT/src/commands/promote-prod-release.yml"
}

@test "push-promotion-tag target-ref defaults to empty string" {
  _assert_target_ref_empty_default "$PROJECT_ROOT/src/commands/push-promotion-tag.yml"
}

@test "github-release-train target-ref defaults to empty string" {
  _assert_target_ref_empty_default "$PROJECT_ROOT/src/commands/github-release-train.yml"
}
