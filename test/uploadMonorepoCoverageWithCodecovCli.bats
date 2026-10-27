# Write a minimal LCOV report with at least one executed line hit.
write_meaningful_lcov() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  cat >"$dest_dir/lcov.info" <<'EOF'
TN:
SF:src/example.ts
DA:1,1
DA:2,0
end_of_record
EOF
}

# Write an LCOV stub with source files but zero hits across all DA lines.
write_zero_hit_lcov() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  cat >"$dest_dir/lcov.info" <<'EOF'
TN:
SF:src/example.ts
DA:1,0
DA:2,0
end_of_record
EOF
}

# Write an LCOV file with no SF: records (empty stub).
write_stub_lcov() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  cat >"$dest_dir/lcov.info" <<'EOF'
TN:
end_of_record
EOF
}

# Write a minimal Istanbul coverage-final.json with non-zero statement hits.
write_meaningful_coverage_final_json() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  cat >"$dest_dir/coverage-final.json" <<'EOF'
{
  "/tmp/example.ts": {
    "path": "/tmp/example.ts",
    "statementMap": {},
    "fnMap": {},
    "branchMap": {},
    "s": { "0": 1, "1": 0 },
    "f": { "0": 1 },
    "b": { "0": [1, 0] }
  }
}
EOF
}

# Write a minimal Cobertura-style coverage.xml with a class node.
write_meaningful_coverage_xml() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  cat >"$dest_dir/coverage.xml" <<'EOF'
<?xml version="1.0" ?>
<coverage line-rate="0.5" branch-rate="0.5" lines-covered="1" lines-valid="2">
  <packages>
    <package name="example" line-rate="0.5" branch-rate="0.5">
      <classes>
        <class name="example.ts" filename="src/example.ts" line-rate="0.5" branch-rate="0.5">
          <lines>
            <line number="1" hits="1"/>
            <line number="2" hits="0"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
}

setup() {
  load "helpers/setup"
  _setup

  COVERAGE_DIR="$TEST_DIR"/fixtures/coverage
  write_meaningful_lcov "$COVERAGE_DIR"/packages/nx-plugin
  write_meaningful_lcov "$COVERAGE_DIR"/e2e/nx-plugin-e2e

  pnpm_mock=$(mock_create)
  pnpm_ls_json="[{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"nx-plugin-e2e\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$pnpm_ls_json"
}

teardown() {
  rm -rf "$COVERAGE_DIR"
}

@test "uploads one coverage report per monorepo package with package flag" {
  codecov_mock=$(mock_create)
  write_meaningful_coverage_xml "$COVERAGE_DIR"/packages/nx-plugin
  write_meaningful_coverage_final_json "$COVERAGE_DIR"/packages/nx-plugin
  write_meaningful_coverage_xml "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  write_meaningful_coverage_final_json "$COVERAGE_DIR"/e2e/nx-plugin-e2e

  # Clear token so assertions match; CI may inject CODECOV_TOKEN.
  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_FAIL_ON_ERROR=true \
  CODECOV_VERBOSE=true \
  CODECOV_DISABLE_SEARCH=true \
  CODECOV_FILES="coverage.xml,coverage-final.json" \
  CODECOV_FLAGS="unit,monorepo" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error --disable-search --file coverage.xml --file coverage-final.json --flag unit --flag monorepo"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error --disable-search --file coverage.xml --file coverage-final.json --flag unit --flag monorepo"
}

@test "sanitizes scoped package names into Codecov-safe flags" {
  scoped_pnpm_ls_json="[{\"name\":\"@chiubaka/lint\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@chiubaka/e2e-tests\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$scoped_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/lint --flag lint --fail-on-error"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @chiubaka/e2e-tests --flag e2e-tests --fail-on-error"
}

@test "normalizes disallowed characters in package-derived flags" {
  weird_pnpm_ls_json="[{\"name\":\"@chiubaka/pkg!!name\",\"path\":\"$TEST_DIR/packages/nx-plugin\"}]"
  mock_set_output "${pnpm_mock}" "$weird_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @chiubaka/pkg!!name --flag pkg-name --fail-on-error"
}

@test "truncates long package-derived flags to Codecov max length" {
  long_name="@scope/abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"
  long_pnpm_ls_json="[{\"name\":\"$long_name\",\"path\":\"$TEST_DIR/packages/nx-plugin\"}]"
  mock_set_output "${pnpm_mock}" "$long_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name $long_name --flag abcdefghijklmnopqrstuvwxyz1234567890abcdefghi --fail-on-error"
}

@test "adds scope back when unscoped flag collides" {
  colliding_pnpm_ls_json="[{\"name\":\"@a/pkg\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@b/pkg\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @a/pkg --flag pkg --fail-on-error"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @b/pkg --flag b-pkg --fail-on-error"
}

@test "resolves collisions introduced by 45-char truncation via scope fallback" {
  long_leaf="abcdefghijklmnopqrstuvwxyz1234567890abcdefghijk"
  colliding_pnpm_ls_json="[{\"name\":\"@alpha/$long_leaf\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"@beta/$long_leaf\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name @alpha/$long_leaf --flag abcdefghijklmnopqrstuvwxyz1234567890abcdefghi --fail-on-error"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name @beta/$long_leaf --flag beta-abcdefghijklmnopqrstuvwxyz1234567890abcd --fail-on-error"
}

@test "fails loudly when unscoped and scoped candidates both collide" {
  colliding_pnpm_ls_json="[{\"name\":\"@a/pkg\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"b-pkg\",\"path\":\"$TEST_DIR/extra/b-pkg\"},{\"name\":\"@b/pkg\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  write_meaningful_lcov "$COVERAGE_DIR"/extra/b-pkg
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: unable to derive unique Codecov flag for package @b/pkg. Unscoped candidate 'pkg' collides with @a/pkg, and scoped candidate 'b-pkg' collides with b-pkg."
}

@test "fails with explicit no-fallback message for unscoped collision" {
  colliding_pnpm_ls_json="[{\"name\":\"pkg\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"pkg!\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$colliding_pnpm_ls_json"
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: unable to derive unique Codecov flag for package pkg!. Unscoped candidate 'pkg' collides with pkg, and no distinct scoped fallback is available."
}

@test "omits token and optional args when unset" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_FAIL_ON_ERROR=false \
  CODECOV_VERBOSE=false \
  CODECOV_REQUIRE_UPLOADS=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin"
}

@test "defaults fail-on-error and verbose to true" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error"
}

@test "skips workspace root package; does not upload full coverage tree under root name" {
  pnpm_ls_with_root="[{\"name\":\"monorepo-root\",\"path\":\"$TEST_DIR\"},{\"name\":\"nx-plugin\",\"path\":\"$TEST_DIR/packages/nx-plugin\"},{\"name\":\"nx-plugin-e2e\",\"path\":\"$TEST_DIR/e2e/nx-plugin-e2e\"}]"
  mock_set_output "${pnpm_mock}" "$pnpm_ls_with_root"
  # Entire tree exists under coverage root, but root must not trigger one -F monorepo-root upload.
  mkdir -p "$COVERAGE_DIR"
  touch "$COVERAGE_DIR"/.placeholder

  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for workspace root package monorepo-root; per-package subdirectories only"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error"
  assert_equal "$(mock_get_call_args "${codecov_mock}" 2)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error"
}

@test "skips packages with missing coverage directories" {
  rm -rf "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  # Entire tree exists under coverage root, but root must not trigger one --name monorepo-root --flag monorepo-root upload.
  CODECOV_TOKEN='' \
  CODECOV_FAIL_ON_ERROR=false \
  CODECOV_VERBOSE=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin-e2e because $COVERAGE_DIR/e2e/nx-plugin-e2e does not exist"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
}

@test "fails when no package coverage reports are uploaded by default" {
  rm -rf "$COVERAGE_DIR"/packages/nx-plugin "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: no coverage reports were uploaded."
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 0
}

@test "allows empty uploads when CODECOV_REQUIRE_UPLOADS is false" {
  rm -rf "$COVERAGE_DIR"/packages/nx-plugin "$COVERAGE_DIR"/e2e/nx-plugin-e2e
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_REQUIRE_UPLOADS=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 0
}

@test "downloads Codecov CLI from cli.codecov.io when not on PATH and skip validation" {
  mock_bin_dir="$(mktemp -d)"
  ln -sfn "$(command -v jq)" "$mock_bin_dir/jq"

  cat >"$mock_bin_dir/curl" <<'EOF'
#! /usr/bin/env bash
prev=
for a in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    if [[ "$*" == *"cli.codecov.io"* ]] && [[ "$*" == *"/codecov"* ]]; then
      {
        printf '#!/usr/bin/env bash\n'
        printf 'exit 0\n'
      } >"$a"
      chmod +x "$a"
      exit 0
    fi
  fi
  prev=$a
done
exit 1
EOF
  chmod +x "$mock_bin_dir/curl"

  CODECOV_TOKEN='' \
  CODECOV_SKIP_VALIDATION=true \
  PATH="$mock_bin_dir:$PATH" \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Downloading Codecov CLI from"
  assert_output --partial "Uploading coverage for package nx-plugin"

  rm -rf "$mock_bin_dir"
}

@test "fails when Codecov CLI download returns non-zero" {
  mock_bin_dir="$(mktemp -d)"
  ln -sfn "$(command -v jq)" "$mock_bin_dir/jq"
  cat >"$mock_bin_dir/curl" <<'EOF'
#! /usr/bin/env bash
if [[ "$*" == *"cli.codecov.io"* && "$*" == *"/codecov" ]]; then
  if [[ "$*" == *" -o "* ]]; then
    exit 7
  fi
fi
exit 0
EOF
  chmod +x "$mock_bin_dir/curl"

  CODECOV_TOKEN='' \
  CODECOV_SKIP_VALIDATION=true \
  PATH="$mock_bin_dir:$PATH" \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: failed to download Codecov CLI"

  rm -rf "$mock_bin_dir"
}

@test "fails when GPG is missing and CLI validation is enabled" {
  # PATH: tools first (no gpg) so download succeeds, then GPG check fails. Include repo scripts on PATH
  # so the upload script is found; only bare utilities are symlinks, not gpg.
  tools_dir="$(mktemp -d)"
  for c in bash jq mktemp rm tr grep cut sed; do
    ln -sfn "$(command -v "$c")" "$tools_dir/$c"
  done
  if command -v arch >/dev/null 2>&1; then
    ln -sfn "$(command -v arch)" "$tools_dir/arch"
  elif command -v /usr/bin/arch >/dev/null 2>&1; then
    ln -sfn /usr/bin/arch "$tools_dir/arch"
  fi
  for u in /bin/uname /usr/bin/uname; do
    if [[ -x "$u" ]]; then
      ln -sfn "$u" "$tools_dir/uname"
      break
    fi
  done

  cat >"$tools_dir/curl" <<'EOF'
#! /usr/bin/env bash
prev=
for a in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    if [[ "$*" == *"cli.codecov.io"* && "$*" == *"/codecov"* ]]; then
      {
        printf '#!/bin/sh\n'
        printf 'exit 0\n'
      } >"$a"
      chmod +x "$a"
      exit 0
    fi
  fi
  prev=$a
done
exit 0
EOF
  chmod +x "$tools_dir/curl"

  CODECOV_TOKEN='' \
  CODECOV_SKIP_VALIDATION=false \
  PATH="$tools_dir:$PROJECT_ROOT/src/scripts" \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "ERROR: gpg is not installed"

  rm -rf "$tools_dir"
}


@test "skips packages whose coverage directory has no report files" {
  rm -rf "$COVERAGE_DIR"/packages/nx-plugin/*
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin because $COVERAGE_DIR/packages/nx-plugin has no meaningful coverage report"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/e2e/nx-plugin-e2e --network-root-folder $TEST_DIR --name nx-plugin-e2e --flag nx-plugin-e2e --fail-on-error"
}

@test "skips stub LCOV reports with no SF records" {
  write_stub_lcov "$COVERAGE_DIR"/packages/nx-plugin
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin because $COVERAGE_DIR/packages/nx-plugin has no meaningful coverage report"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
}

@test "skips zero-hit LCOV reports by default" {
  write_zero_hit_lcov "$COVERAGE_DIR"/packages/nx-plugin
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Skipping coverage upload for nx-plugin because $COVERAGE_DIR/packages/nx-plugin has no meaningful coverage report"
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 1
}

@test "uploads zero-hit LCOV when CODECOV_SKIP_ZERO_HIT is false" {
  write_zero_hit_lcov "$COVERAGE_DIR"/packages/nx-plugin
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_SKIP_ZERO_HIT=false \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 2
  assert_equal "$(mock_get_call_args "${codecov_mock}" 1)" "-v upload-coverage --dir $COVERAGE_DIR/packages/nx-plugin --network-root-folder $TEST_DIR --name nx-plugin --flag nx-plugin --fail-on-error"
}

@test "skips packages when configured CODECOV_FILES are missing" {
  codecov_mock=$(mock_create)

  CODECOV_TOKEN='' \
  CODECOV_FILES="coverage.xml,coverage-final.json" \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  CODECOV_BINARY="${codecov_mock}" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_failure
  assert_output --partial "Skipping coverage upload for nx-plugin because $COVERAGE_DIR/packages/nx-plugin has no meaningful coverage report"
  assert_output --partial "ERROR: no coverage reports were uploaded."
  assert_equal "$(mock_get_call_num "${codecov_mock}")" 0
}

@test "ignores checksum stdout so resolved codecov command stays executable path" {
  mock_bin_dir="$(mktemp -d)"
  run_home="$(mktemp -d)"
  ln -sfn "$(command -v jq)" "$mock_bin_dir/jq"
  ln -sfn "$(command -v mktemp)" "$mock_bin_dir/mktemp"
  ln -sfn "$(command -v rm)" "$mock_bin_dir/rm"
  ln -sfn "$(command -v uname)" "$mock_bin_dir/uname"
  ln -sfn "$(command -v tr)" "$mock_bin_dir/tr"
  ln -sfn "$(command -v grep)" "$mock_bin_dir/grep"
  ln -sfn "$(command -v cut)" "$mock_bin_dir/cut"

  cat >"$mock_bin_dir/curl" <<'EOF'
#! /usr/bin/env bash
last="${@: -1}"
if [[ "$*" == *"https://keybase.io/codecovsecops/pgp_keys.asc"* ]]; then
  printf 'fake-key'
  exit 0
fi
if [[ "$*" == *" -o "* ]] && [[ "$last" == */codecov ]]; then
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "codecov-ran\n"\n'
  } >"$last"
  chmod +x "$last"
  exit 0
fi
if [[ "$*" == *" -O "* ]]; then
  printf 'fake' >"$(basename "$last")"
  exit 0
fi
exit 0
EOF
  chmod +x "$mock_bin_dir/curl"

  cat >"$mock_bin_dir/gpg" <<'EOF'
#! /usr/bin/env bash
exit 0
EOF
  chmod +x "$mock_bin_dir/gpg"

  cat >"$mock_bin_dir/shasum" <<'EOF'
#! /usr/bin/env bash
printf 'codecov: OK\n'
exit 0
EOF
  chmod +x "$mock_bin_dir/shasum"

  HOME="$run_home" \
  CODECOV_TOKEN='' \
  CODECOV_SKIP_VALIDATION=false \
  PATH="$mock_bin_dir:$PROJECT_ROOT/src/scripts:$PATH" \
  MONOREPO_ROOT="$TEST_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PNPM_BINARY="${pnpm_mock}" \
  run uploadMonorepoCoverageWithCodecovCli.sh

  assert_success
  assert_output --partial "Codecov CLI integrity verified"
  assert_output --partial "Uploading coverage for package nx-plugin"
  assert_output --partial "codecov-ran"

  rm -rf "$mock_bin_dir" "$run_home"
}
