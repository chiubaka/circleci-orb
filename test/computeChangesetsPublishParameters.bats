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
  local repo_dir
  local output_path
  repo_dir="$1"
  output_path="$repo_dir/out.json"
  CIRCLE_SHA1="$(git -C "$repo_dir" rev-parse HEAD)" \
    BASE_REVISION=master \
    OUTPUT_PATH="$output_path" \
    bash -c "cd \"$repo_dir\" && bash \"$PROJECT_ROOT/src/scripts/computeChangesetsPublishParameters.sh\" >/dev/null"
  cat "$output_path"
}

@test "returns true when changelog path changes" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' '## 1.0.1' >>"$repo_dir/packages/pkg-a/CHANGELOG.md"
  git -C "$repo_dir" add packages/pkg-a/CHANGELOG.md
  git -C "$repo_dir" commit -m "docs: changelog update" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish": true}'
}

@test "returns true when package version field changes" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' '{"name":"pkg-a","version":"1.1.0"}' >"$repo_dir/packages/pkg-a/package.json"
  git -C "$repo_dir" add packages/pkg-a/package.json
  git -C "$repo_dir" commit -m "feat: bump version" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish": true}'
}

@test "returns false when no changelog or version changes exist" {
  repo_dir="$(create_repo_with_remote)"
  printf '%s\n' 'notes' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "docs: add readme" >/dev/null

  result="$(run_compute_script "$repo_dir")"
  assert_equal "$result" '{"run-changesets-publish": false}'
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
  git -C "$source_dir" commit -m "feat: version bump" >/dev/null
  git -C "$source_dir" push >/dev/null

  git clone --depth=1 --branch master "file://$remote_dir" "$shallow_dir" >/dev/null 2>&1

  run env CIRCLE_SHA1="$(git -C "$shallow_dir" rev-parse HEAD)" BASE_REVISION=master OUTPUT_PATH="$output_path" \
    bash -c "cd \"$shallow_dir\" && bash \"$PROJECT_ROOT/src/scripts/computeChangesetsPublishParameters.sh\""

  assert_success
  run cat "$output_path"
  assert_output '{"run-changesets-publish": true}'
}
