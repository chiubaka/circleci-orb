setup() {
  load "helpers/setup"
  _setup
}

create_repo_with_remote() {
  local remote_dir
  local source_dir
  local work_dir

  remote_dir="$BATS_TEST_TMPDIR/remote.git"
  source_dir="$BATS_TEST_TMPDIR/source"
  work_dir="$BATS_TEST_TMPDIR/work"

  git init --bare "$remote_dir" >/dev/null
  git init -b master "$source_dir" >/dev/null
  git -C "$source_dir" config user.email test@example.com
  git -C "$source_dir" config user.name "Test User"

  mkdir -p "$source_dir/packages/pkg-a"
  printf '%s\n' '{"name":"pkg-a","version":"1.0.0"}' >"$source_dir/packages/pkg-a/package.json"
  printf '%s\n' '# Changelog' >"$source_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$source_dir" add .
  git -C "$source_dir" commit -m "initial" >/dev/null
  git -C "$source_dir" remote add origin "$remote_dir"
  git -C "$source_dir" push -u origin master >/dev/null

  git clone "$remote_dir" "$work_dir" >/dev/null 2>&1
  git -C "$work_dir" config user.email test@example.com
  git -C "$work_dir" config user.name "Test User"
  printf '%s\n' "$work_dir"
}

run_compute_script() {
  local repo_dir="$1"
  shift
  local output_path="$repo_dir/out.json"
  local -a env_args=(
    "CIRCLE_SHA1=$(git -C "$repo_dir" rev-parse HEAD)"
    BASE_REVISION=master
    "OUTPUT_PATH=$output_path"
  )
  while (($# > 0)); do
    env_args+=("$1")
    shift
  done
  env "${env_args[@]}" bash -c "cd \"$repo_dir\" && bash \"$PROJECT_ROOT/src/scripts/computeChangesetsPublishParameters.sh\" >/dev/null"
  cat "$output_path"
}

write_open_cycle() {
  local repo_dir="$1"
  local cycle_id="${2:-2026.07.08.1}"
  mkdir -p "$repo_dir/.releases/$cycle_id/rc1"
  printf '%s\n' "release: \"$cycle_id\"" "openedAt: \"2026-07-08T12:00:00Z\"" \
    >"$repo_dir/.releases/$cycle_id/cycle.yml"
  printf '%s\n' "packages: {}" >"$repo_dir/.releases/$cycle_id/rc1/manifest.yml"
}

write_promoted_cycle() {
  local repo_dir="$1"
  local cycle_id="${2:-2026.07.08.1}"
  local promoted_at="${3:-\"2026-07-09T18:00:00Z\"}"
  mkdir -p "$repo_dir/.releases/$cycle_id/rc1"
  printf '%s\n' \
    "release: \"$cycle_id\"" \
    "openedAt: \"2026-07-08T12:00:00Z\"" \
    "promotedAt: ${promoted_at}" \
    >"$repo_dir/.releases/$cycle_id/cycle.yml"
  printf '%s\n' "packages: {}" >"$repo_dir/.releases/$cycle_id/rc1/manifest.yml"
}

@test "returns both true for version-packages subject with changelog and open cycle" {
  repo_dir="$(create_repo_with_remote)"
  write_open_cycle "$repo_dir"
  printf '%s\n' '## 1.0.1' >>"$repo_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$repo_dir" add packages/pkg-a/CHANGELOG.md .releases
  git -C "$repo_dir" commit -m "chore(release): version packages (pkg-a@1.0.1)" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":true,"offer-promote-prod":true}'
}

@test "returns publish true and offer false for version-packages without open cycle" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  git -C "$repo_dir" add packages/pkg-a/package.json
  git -C "$repo_dir" commit -m "chore(release): version packages (pkg-a@1.1.0)" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":true,"offer-promote-prod":false}'
}

@test "returns both false when changelog changes without version-packages subject" {
  repo_dir="$(create_repo_with_remote)"
  write_open_cycle "$repo_dir"
  printf '%s\n' '## 1.0.1' >>"$repo_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$repo_dir" add packages/pkg-a/CHANGELOG.md .releases
  git -C "$repo_dir" commit -m "docs: changelog update" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false}'
}

@test "returns both false for finalize subject even with version path signal" {
  repo_dir="$(create_repo_with_remote)"
  write_promoted_cycle "$repo_dir"
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  printf '%s\n' '## 1.1.0' >>"$repo_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$repo_dir" add packages/pkg-a/package.json packages/pkg-a/CHANGELOG.md .releases
  git -C "$repo_dir" commit -m "chore(release): finalize 2026.07.08.1 for production" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false}'
}

@test "returns offer false when cycle already has promotedAt" {
  repo_dir="$(create_repo_with_remote)"
  write_promoted_cycle "$repo_dir"
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  git -C "$repo_dir" add packages/pkg-a/package.json .releases
  git -C "$repo_dir" commit -m "chore(release): version packages (pkg-a@1.1.0)" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":true,"offer-promote-prod":false}'
}

@test "treats quoted empty promotedAt as open" {
  repo_dir="$(create_repo_with_remote)"
  write_promoted_cycle "$repo_dir" "2026.07.08.1" '""'
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  git -C "$repo_dir" add packages/pkg-a/package.json .releases
  git -C "$repo_dir" commit -m "chore(release): version packages (pkg-a@1.1.0)" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":true,"offer-promote-prod":true}'
}

@test "returns offer false when tip cycle is promoted even if another cycle is open" {
  repo_dir="$(create_repo_with_remote)"
  write_promoted_cycle "$repo_dir" "2026.07.08.1"
  write_open_cycle "$repo_dir" "2026.07.01.1"
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  git -C "$repo_dir" add packages/pkg-a/package.json .releases
  git -C "$repo_dir" commit -m "chore(release): version packages (pkg-a@1.1.0)" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":true,"offer-promote-prod":false}'
}

@test "returns both false when no changelog or version changes exist" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false}'
}

@test "recovers from shallow clone merge-base failure path" {
  local remote_dir
  local source_dir
  local shallow_dir
  local output_path

  remote_dir="$BATS_TEST_TMPDIR/remote-shallow.git"
  source_dir="$BATS_TEST_TMPDIR/source-shallow"
  shallow_dir="$BATS_TEST_TMPDIR/shallow"
  output_path="$BATS_TEST_TMPDIR/shallow-out.json"

  git init --bare "$remote_dir" >/dev/null
  git init -b master "$source_dir" >/dev/null
  git -C "$source_dir" config user.email test@example.com
  git -C "$source_dir" config user.name "Test User"

  mkdir -p "$source_dir/packages/pkg-a"
  printf '%s\n' '{"name":"pkg-a","version":"1.0.0"}' >"$source_dir/packages/pkg-a/package.json"
  printf '%s\n' '# Changelog' >"$source_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$source_dir" add .
  git -C "$source_dir" commit -m "initial" >/dev/null
  git -C "$source_dir" remote add origin "$remote_dir"
  git -C "$source_dir" push -u origin master >/dev/null

  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$source_dir/packages/pkg-a/package.json"
  git -C "$source_dir" add packages/pkg-a/package.json
  git -C "$source_dir" commit -m "chore(release): version packages (pkg-a@1.1.0)" >/dev/null
  git -C "$source_dir" push >/dev/null

  git clone --depth=1 --branch master "file://$remote_dir" "$shallow_dir" >/dev/null 2>&1

  run env CIRCLE_SHA1="$(git -C "$shallow_dir" rev-parse HEAD)" BASE_REVISION=master OUTPUT_PATH="$output_path" \
    bash -c "cd \"$shallow_dir\" && bash \"$PROJECT_ROOT/src/scripts/computeChangesetsPublishParameters.sh\""

  assert_success
  run cat "$output_path"
  assert_output '{"run-changesets-publish":true,"offer-promote-prod":false}'
}

@test "omits PR metadata by default" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(
    run_compute_script "$repo_dir" \
      CIRCLE_PULL_REQUEST='https://github.com/org/repo/pull/42' \
      CIRCLE_PR_NUMBER='42'
  )"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false}'
}

@test "includes PR metadata when enabled" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(
    run_compute_script "$repo_dir" \
      CIRCLE_PULL_REQUEST='https://github.com/org/repo/pull/42' \
      CIRCLE_PR_NUMBER='42' \
      INCLUDE_PR_METADATA=true
  )"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false,"circle_pull_request":"https://github.com/org/repo/pull/42","circle_pr_number":"42"}'
}

@test "derives PR number from pull request URL when number env is empty" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(
    run_compute_script "$repo_dir" \
      CIRCLE_PULL_REQUEST='https://github.com/org/repo/pull/99' \
      CIRCLE_PR_NUMBER='' \
      INCLUDE_PR_METADATA=true
  )"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false,"circle_pull_request":"https://github.com/org/repo/pull/99","circle_pr_number":"99"}'
}

@test "emits empty PR metadata strings when env vars are unset" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(
    run_compute_script "$repo_dir" \
      CIRCLE_PULL_REQUEST='' \
      CIRCLE_PR_NUMBER='' \
      INCLUDE_PR_METADATA=true
  )"
  assert_equal "$result" '{"run-changesets-publish":false,"offer-promote-prod":false,"circle_pull_request":"","circle_pr_number":""}'
}

@test "merges computed parameters into an existing output file" {
  repo_dir="$(create_repo_with_remote)"
  output_path="$repo_dir/out.json"
  printf '%s\n' '{"custom-parameter": "keep"}' >"$output_path"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(
    run_compute_script "$repo_dir" \
      CIRCLE_PULL_REQUEST='https://github.com/org/repo/pull/7' \
      CIRCLE_PR_NUMBER='7' \
      INCLUDE_PR_METADATA=true
  )"
  assert_equal "$result" '{"custom-parameter":"keep","run-changesets-publish":false,"offer-promote-prod":false,"circle_pull_request":"https://github.com/org/repo/pull/7","circle_pr_number":"7"}'
}
